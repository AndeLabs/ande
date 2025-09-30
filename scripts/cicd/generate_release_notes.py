# =============================================================================
# scripts/cicd/generate_release_notes.py
# Genera release notes a partir de commits
# =============================================================================

#!/usr/bin/env python3
import os
import sys
from google import genai
from google.genai import types

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print("Error: GEMINI_API_KEY no configurada")
    sys.exit(1)

client = genai.Client(api_key=GEMINI_API_KEY)

# Leer mensajes de commit
try:
    with open("COMMITS_MENSAJES.txt", "r", encoding="utf-8") as f:
        commit_messages = f.read()
except FileNotFoundError:
    print("Error: COMMITS_MENSAJES.txt no encontrado")
    sys.exit(1)

prompt = f"""
Eres un Release Manager experto para proyectos blockchain.

Analiza estos mensajes de commit y genera release notes profesionales en Markdown.

**MENSAJES DE COMMIT:**
```
{commit_messages}
```

**INSTRUCCIONES:**
Clasifica cada cambio en:

### 🚀 Nuevas Funcionalidades (feat)
- Características nuevas que añaden valor al usuario

### 🐛 Correcciones de Errores (fix)
- Bugs solucionados

### 📚 Documentación (docs)
- Mejoras en documentación

### ⚡ Performance (perf)
- Optimizaciones de rendimiento

### 🔧 Mantenimiento (chore, refactor, test, ci)
- Cambios internos que no afectan al usuario

### 🔒 Seguridad (security)
- Fixes de seguridad o mejoras

**REGLAS:**
- NO incluyas categorías vacías
- Reformula mensajes para que sean legibles
- No uses prefijos tipo "feat:", "fix:" en el texto final
- Sé conciso pero informativo
- Ordena por impacto (más importante primero)
"""

try:
    print("🤖 Generando release notes...")
    response = client.models.generate_content(
        model="gemini-2.0-flash-001",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.2,
            max_output_tokens=2048,
        )
    )
    
    # Guardar release notes
    with open("RELEASE_NOTES.md", "w", encoding="utf-8") as f:
        f.write(f"# 📋 Release Notes\n\n")
        f.write(f"_Generado automáticamente_\n\n")
        f.write(response.text)
    
    print("✅ Release notes generadas en RELEASE_NOTES.md")
    
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)

