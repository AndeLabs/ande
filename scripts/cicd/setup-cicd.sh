#!/bin/bash
# =============================================================================
# scripts/setup-cicd.sh
# Script de configuración del pipeline CI/CD de AndeChain
# =============================================================================

set -e

echo "🚀 Configurando CI/CD para AndeChain"
echo "===================================="

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 1. Verificar estructura de directorios
echo ""
echo "📁 Verificando estructura del proyecto..."

required_dirs=(
    "andechain/contracts"
    "andechain/infra"
    "scripts/cicd"
    ".github/workflows"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        print_success "Directorio $dir existe"
    else
        print_warning "Creando directorio $dir"
        mkdir -p "$dir"
    fi
done

# 2. Crear scripts de CI/CD si no existen
echo ""
echo "📝 Verificando scripts de CI/CD..."

# Script de Code Review
if [ ! -f "scripts/cicd/ai_code_review.py" ]; then
    print_warning "Creando scripts/cicd/ai_code_review.py"
    cat > scripts/cicd/ai_code_review.py << 'ENDOFFILE'
#!/usr/bin/env python3
# AI Code Review Script
import os
import sys
from google import genai
from google.genai import types

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print("Error: GEMINI_API_KEY no configurada")
    sys.exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)

try:
    with open("pr_diff.txt", "r", encoding="utf-8") as f:
        pr_diff = f.read()
except FileNotFoundError:
    print("Error: pr_diff.txt no encontrado")
    sys.exit(1)

MAX_DIFF_SIZE = 15000
if len(pr_diff) > MAX_DIFF_SIZE:
    pr_diff = pr_diff[:MAX_DIFF_SIZE] + "\n... (diff truncado)"

SYSTEM_PROMPT = """
Eres PrometeoDEV, experto en Solidity, EVM y arquitecturas de rollup modular.

Revisa este código enfocándote en:

1. 🔴 CRÍTICO:
   - Bugs y errores lógicos
   - Vulnerabilidades de seguridad (reentrancy, overflow, etc.)
   - Gas inefficiencies críticas
   - Problemas de acceso/permisos

2. 🟡 IMPORTANTE:
   - Mejores prácticas de Solidity
   - Patrones de diseño
   - Calidad del código

3. 🟢 SUGERENCIAS:
   - Optimizaciones
   - Legibilidad
   - Documentación

Formato de respuesta:

## 🔍 Resumen
[Evaluación general]

### 🔴 Crítico
- **Ubicación** - Descripción y solución

### 🟡 Importante
[Similar]

### 🟢 Sugerencias
[Similar]

## ✅ Aspectos Positivos
[Lista lo bueno]
"""

prompt = f"{SYSTEM_PROMPT}\n\n**DIFF:**\n```diff\n{pr_diff}\n```"

try:
    print("🤖 Realizando code review...")
    response = client.models.generate_content(
        model="gemini-2.0-flash-001",
        contents=prompt,
        config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=2048)
    )
    
    with open("ai_review.md", "w", encoding="utf-8") as f:
        f.write(response.text)
    print("✅ Review completado")
except Exception as e:
    print(f"❌ Error: {e}")
    with open("ai_review.md", "w", encoding="utf-8") as f:
        f.write("## ⚠️ Error en AI Review\n\nNo se pudo completar.")
    sys.exit(0)
ENDOFFILE
    chmod +x scripts/cicd/ai_code_review.py
fi

# Script de Documentación
if [ ! -f "scripts/cicd/generate_docs.py" ]; then
    print_warning "Creando scripts/cicd/generate_docs.py"
    cat > scripts/cicd/generate_docs.py << 'ENDOFFILE'
#!/usr/bin/env python3
# Documentation Generation Script
import os
import sys
from pathlib import Path
from google import genai
from google.genai import types

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print("Error: GEMINI_API_KEY no configurada")
    sys.exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)

def collect_context():
    context = {}
    files = [
        "package.json",
        "hardhat.config.ts",
        "README.md",
        "andechain/contracts/contracts/*.sol"
    ]
    
    for pattern in files:
        for file in Path(".").rglob(pattern):
            if file.is_file():
                with open(file, "r", encoding="utf-8") as f:
                    context[str(file)] = f.read()[:2000]
    
    return context

def generate_docs():
    try:
        print("📝 Recolectando contexto...")
        context = collect_context()
        
        context_str = "\n\n".join([
            f"### {f}\n```\n{c[:500]}\n```" 
            for f, c in context.items()
        ])
        
        prompt = f"""
Eres un documentador técnico experto en blockchain y EVM rollups.

Genera documentación profesional en Markdown para AndeChain, un rollup soberano EVM sobre Celestia.

**CONTEXTO DEL PROYECTO:**
{context_str}

**ESTRUCTURA:**

## 🚀 AndeChain - Rollup Soberano EVM

### Resumen Ejecutivo
[Descripción concisa]

### Arquitectura
- Capa de Ejecución: Reth (EVM)
- Capa de Secuenciación: Evolve/Rollkit
- Disponibilidad de Datos: Celestia

### Smart Contracts
[Lista y descripción de contratos]

### Desarrollo Local
[Pasos para setup]

### Despliegue
[Proceso de deployment]

### Recursos
[Links y referencias]

Sé técnico pero accesible. Usa emojis moderadamente.
"""
        
        print("🤖 Generando documentación...")
        response = client.models.generate_content(
            model="gemini-2.0-flash-001",
            contents=prompt,
            config=types.GenerateContentConfig(temperature=0.3, max_output_tokens=4096)
        )
        
        with open("DOCUMENTACION_AUTOMATICA.md", "w", encoding="utf-8") as f:
            f.write(response.text)
        
        print(f"✅ Documentación generada")
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    generate_docs()
ENDOFFILE
    chmod +x scripts/cicd/generate_docs.py
fi

# Script de Release Notes
if [ ! -f "scripts/cicd/generate_release_notes.py" ]; then
    print_warning "Creando scripts/cicd/generate_release_notes.py"
    cat > scripts/cicd/generate_release_notes.py << 'ENDOFFILE'
#!/usr/bin/env python3
# Release Notes Generation
import os
import sys
from google import genai
from google.genai import types

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print("Error: GEMINI_API_KEY no configurada")
    sys.exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)

try:
    with open("COMMITS_MENSAJES.txt", "r", encoding="utf-8") as f:
        commits = f.read()
except FileNotFoundError:
    print("Error: COMMITS_MENSAJES.txt no encontrado")
    sys.exit(1)

prompt = f"""
Genera release notes profesionales para AndeChain.

**COMMITS:**
{commits}

Clasifica en:
### 🚀 Nuevas Funcionalidades
### 🐛 Correcciones
### 📚 Documentación
### ⚡ Performance
### 🔒 Seguridad
### 🔧 Mantenimiento

Solo incluye categorías con contenido. Sé conciso.
"""

try:
    response = client.models.generate_content(
        model="gemini-2.0-flash-001",
        contents=prompt,
        config=types.GenerateContentConfig(temperature=0.2, max_output_tokens=2048)
    )
    
    with open("RELEASE_NOTES.md", "w", encoding="utf-8") as f:
        f.write(f"# 📋 Release