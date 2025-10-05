#!/bin/bash
# Script wrapper para ejecutar auto-verify.py desde el directorio correcto

# Obtener el directorio donde está este script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# El directorio andechain/ es el padre del directorio scripts/
ANDECHAIN_DIR="$(dirname "$SCRIPT_DIR")"

# Cambiar al directorio andechain
cd "$ANDECHAIN_DIR" || exit 1

# Ejecutar el script de Python
python3 scripts/auto-verify.py "$@"
