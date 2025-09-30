# =============================================================================
# scripts/cicd/ai_code_review.py
# Realiza code review automático con Gemini
# =============================================================================

#!/usr/bin/env python3
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

# Leer el diff del PR
try:
    with open("pr_diff.txt", "r", encoding="utf-8") as f:
        pr_diff = f.read()
except FileNotFoundError:
    print("Error: pr_diff.txt no encontrado")
    sys.exit(1)

# Limitar tamaño del diff (Gemini tiene límites)
MAX_DIFF_SIZE = 15000
if len(pr_diff) > MAX_DIFF_SIZE:
    pr_diff = pr_diff[:MAX_DIFF_SIZE] + "\n... (diff truncado por tamaño)"

SYSTEM_PROMPT = """
Eres PrometeoDEV, un experto mundial en desarrollo blockchain con Go, especializado en Cosmos SDK y arquitecturas modulares.

Tu misión es revisar este Pull Request como un guardián de calidad, seguridad y buenas prácticas.

**PRIORIDADES DE REVISIÓN:**

1. **🔴 CRÍTICO - Errores y Bugs:**
   - Errores lógicos
   - Race conditions
   - Nil pointer dereferences
   - Pánico potencial
   - Comportamiento incorrecto

2. **🔴 CRÍTICO - Seguridad:**
   - No-determinismo (causa de forks en blockchain)
   - Vectores de DoS (loops infinitos, gas excesivo)
   - Validación de mensajes (Msg)
   - Control de acceso inadecuado
   - Vulnerabilidades en el manejo de state

3. **🟡 MEDIO - Estilo y Mejores Prácticas:**
   - Idiomas de Go
   - Patrones de Cosmos SDK
   - Manejo de errores
   - Legibilidad

4. **🟢 BAJO - Sugerencias:**
   - Optimizaciones
   - Refactorizaciones
   - Nombres de variables
   - Comentarios

**FORMATO DE RESPUESTA:**

Si encuentras problemas:

## 🔍 Resumen de Revisión

[Breve párrafo sobre la calidad general]

### 🔴 Crítico
- **Archivo:línea** - Descripción del problema
  ```go
  // Código problemático
  ```
  **Solución sugerida:** [explicación]

### 🟡 Medio
[Similar al anterior]

### 🟢 Sugerencias
[Similar al anterior]

## ✅ Aspectos Positivos
- [Lista cosas bien hechas]

Si NO encuentras problemas:
## ✅ Revisión Aprobada

El código se ve bien. Sigue buenas prácticas de Go y Cosmos SDK.

**Aspectos destacados:**
- [Lista 2-3 cosas positivas]

**TONO:** Constructivo, educativo, explica el "por qué" de tus sugerencias.
"""

prompt = f"""
{SYSTEM_PROMPT}

**DIFF DEL PULL REQUEST:**
```diff
{pr_diff}
```

Realiza tu revisión siguiendo el formato especificado.
"""

try:
    print("🤖 Realizando code review con PrometeoDEV AI...")
    
    response = client.models.generate_content(
        model="gemini-2.0-flash-001",
        contents=prompt,
        config=types.GenerateContentConfig(
            temperature=0.2,
            max_output_tokens=2048,
        )
    )
    
    # Guardar review
    with open("ai_review.md", "w", encoding="utf-8") as f:
        f.write(response.text)
    
    print("✅ Code review completado")
    print(f"📊 Longitud de review: {len(response.text)} caracteres")
    
except Exception as e:
    print(f"❌ Error durante code review: {e}")
    # No fallar el workflow si el review falla
    with open("ai_review.md", "w", encoding="utf-8") as f:
        f.write("## ⚠️ Error en AI Review\n\nNo se pudo completar el review automático.")
    sys.exit(0)  # Exit con 0 para no bloquear el PR