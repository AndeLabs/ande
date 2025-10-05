#!/usr/bin/env python3
"""
Script de verificación automática de contratos en Blockscout
Lee las direcciones desplegadas y verifica cada contrato automáticamente.

Uso:
    python scripts/auto-verify.py
"""

import json
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# Configuración
CHAIN_ID = "1234"
RPC_URL = "http://localhost:8545"
BLOCKSCOUT_API = "http://localhost:4000/api"
COMPILER_VERSION = "v0.8.25+commit.b61c2a91"

# Colores ANSI para terminal
class Colors:
    BLUE = '\033[0;34m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    NC = '\033[0m'  # No Color

def print_header(text: str):
    """Imprime un encabezado formateado"""
    print(f"{Colors.BLUE}{'=' * 50}{Colors.NC}")
    print(f"{Colors.BLUE}  {text}{Colors.NC}")
    print(f"{Colors.BLUE}{'=' * 50}{Colors.NC}")
    print()

def print_success(text: str):
    """Imprime un mensaje de éxito"""
    print(f"{Colors.GREEN}✓ {text}{Colors.NC}")

def print_warning(text: str):
    """Imprime una advertencia"""
    print(f"{Colors.YELLOW}⚠ {text}{Colors.NC}")

def print_error(text: str):
    """Imprime un error"""
    print(f"{Colors.RED}✗ {text}{Colors.NC}")

def find_broadcast_file() -> Path:
    """Encuentra el archivo de broadcast más reciente"""
    # Detectar si estamos en andechain/ o en la raíz
    if Path("contracts/broadcast").exists():
        broadcast_base = Path("contracts/broadcast")
    elif Path("broadcast").exists():
        broadcast_base = Path("broadcast")
    else:
        broadcast_base = Path("contracts/broadcast")

    if not broadcast_base.exists():
        print_error(f"No se encontró el directorio de broadcast: {broadcast_base}")
        print_warning("Ejecuta primero un script de despliegue")
        sys.exit(1)

    # Buscar en todos los subdirectorios de scripts
    all_run_files = []
    for script_dir in broadcast_base.iterdir():
        if not script_dir.is_dir():
            continue

        chain_dir = script_dir / CHAIN_ID
        if not chain_dir.exists():
            continue

        # Buscar run-latest.json
        latest_file = chain_dir / "run-latest.json"
        if latest_file.exists():
            all_run_files.append(latest_file)

        # Buscar cualquier archivo run-*.json
        for run_file in chain_dir.glob("run-*.json"):
            if run_file.name != "run-latest.json":
                all_run_files.append(run_file)

    if not all_run_files:
        print_error("No se encontró ningún archivo de deployment")
        print_warning("Ejecuta primero un script de despliegue:")
        print("  cd contracts")
        print("  forge script script/DeployBridge.s.sol --rpc-url local --broadcast --legacy")
        sys.exit(1)

    # Ordenar por timestamp y tomar el más reciente
    all_run_files.sort(key=lambda x: x.stat().st_mtime, reverse=True)
    return all_run_files[0]

def parse_deployments(broadcast_file: Path) -> Dict[str, str]:
    """
    Parsea el archivo de broadcast y extrae las direcciones de los contratos
    Retorna un diccionario {nombre_contrato: dirección}
    """
    with open(broadcast_file, 'r') as f:
        data = json.load(f)

    deployments = {}

    # Parsear transacciones
    for tx in data.get('transactions', []):
        contract_name = tx.get('contractName')
        contract_address = tx.get('contractAddress')

        if contract_name and contract_address:
            # No verificar los proxies directamente, se verifican por su implementación
            if "Proxy" not in contract_name:
                 deployments[contract_name] = contract_address

    return deployments

def get_contract_path(contract_name: str) -> str:
    """Retorna el path completo del contrato para verificación."""
    # Detectar si estamos en andechain/ o en contracts/
    if Path("contracts/src").exists():
        base_path = Path("contracts")
    elif Path("src").exists():
        base_path = Path(".")
    else:
        base_path = Path("contracts")

    possible_paths = [
        base_path / "src" / f"{contract_name}.sol",
        base_path / "src" / "mocks" / f"{contract_name}.sol",
        base_path / "script" / f"{contract_name}.s.sol",
        base_path / "lib" / "openzeppelin-contracts" / "contracts" / "proxy" / "ERC1967" / f"{contract_name}.sol"
    ]

    # Casos especiales para contratos definidos en el script de despliegue
    if contract_name == "MockBlobstream":
        return f"script/DeployEcosystem.s.sol:{contract_name}"
    if contract_name == "MockABOB" or contract_name == "MockUSDC":
        return f"script/DeployBridge.s.sol:{contract_name}"

    for path in possible_paths:
        if path.exists():
            # Retorna el path relativo a la raíz del proyecto de foundry
            return str(path.relative_to(base_path)) + f":{contract_name}"

    # Fallback por si no se encuentra
    return f"src/{contract_name}.sol:{contract_name}"

def verify_contract(name: str, address: str, constructor_args: str = None) -> bool:
    """
    Verifica un contrato en Blockscout usando forge verify-contract
    Retorna True si la verificación fue exitosa
    """
    contract_path = get_contract_path(name)

    print(f"\n{Colors.YELLOW}Verificando: {name}{Colors.NC}")
    print(f"  Dirección: {address}")
    print(f"  Path: {contract_path}")

    # Determinar el directorio raíz para forge
    if Path("contracts/foundry.toml").exists():
        root_dir = 'contracts'
    elif Path("foundry.toml").exists():
        root_dir = '.'
    else:
        root_dir = 'contracts'

    cmd = [
        'forge', 'verify-contract',
        '--chain-id', CHAIN_ID,
        '--compiler-version', COMPILER_VERSION,
        '--verifier', 'blockscout',
        '--verifier-url', BLOCKSCOUT_API,
        '--root', root_dir,
        address,
        contract_path
    ]

    # Si hay argumentos de constructor, agregarlos
    if constructor_args:
        cmd.extend(['--constructor-args', constructor_args])
        print(f"  Constructor args: {constructor_args[:50]}...")

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=120  # Aumentado a 2 minutos
        )

        output = result.stdout + result.stderr

        # Mostrar output para debugging
        if result.returncode == 0:
            if 'successfully verified' in output.lower():
                print_success(f"{name} verificado exitosamente")
                return True
            elif 'already verified' in output.lower() or 'contract source code already verified' in output.lower():
                print_success(f"{name} ya estaba verificado")
                return True

        # Si llegamos aquí, hubo algún problema
        print_error(f"Error al verificar {name}")
        print(f"  Código de salida: {result.returncode}")

        # Mostrar las primeras líneas del error
        if result.stderr:
            error_lines = result.stderr.split('\n')[:5]
            for line in error_lines:
                if line.strip():
                    print(f"  {line[:100]}")

        if result.stdout:
            stdout_lines = result.stdout.split('\n')[:3]
            for line in stdout_lines:
                if line.strip():
                    print(f"  {line[:100]}")

        return False

    except subprocess.TimeoutExpired:
        print_error(f"Timeout al verificar {name} (>120s)")
        return False
    except Exception as e:
        print_error(f"Excepción al verificar {name}: {str(e)}")
        return False

def main():
    """Función principal"""
    print_header("ANDECHAIN - VERIFICACIÓN AUTOMÁTICA DE CONTRATOS")

    # Buscar archivo de broadcast
    print("Buscando archivo de deployment...")
    broadcast_file = find_broadcast_file()
    print_success(f"Encontrado: {broadcast_file}")
    print()

    # Parsear deployments
    print("Parseando direcciones de contratos...")
    deployments = parse_deployments(broadcast_file)

    if not deployments:
        print_error("No se encontraron contratos desplegados")
        sys.exit(1)

    print_success(f"Encontrados {len(deployments)} contratos")
    print()

    # Listar contratos
    print("Contratos a verificar:")
    for name, address in deployments.items():
        print(f"  {name}: {address}")
    print()

    # Verificar cada contrato
    print_header("INICIANDO VERIFICACIÓN")

    success_count = 0
    total_count = len(deployments)

    for name, address in deployments.items():
        if verify_contract(name, address):
            success_count += 1

    # Resumen
    print()
    print_header("RESUMEN")
    print(f"Total de contratos: {total_count}")
    print_success(f"Verificados exitosamente: {success_count}")

    if success_count < total_count:
        print_warning(f"Fallidos o saltados: {total_count - success_count}")

    print()
    print("Visita Blockscout para ver los contratos verificados:")
    print(f"{Colors.BLUE}http://localhost:4000{Colors.NC}")
    print()

    if success_count == total_count:
        print_success("¡Todos los contratos verificados exitosamente!")
        sys.exit(0)
    else:
        print_warning("Algunos contratos no pudieron ser verificados")
        sys.exit(1)

if __name__ == '__main__':
    main()
