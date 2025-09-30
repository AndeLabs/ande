#!/usr/bin/env python3
# =============================================================================
# scripts/cicd/generate_docs.py
# Genera documentación del proyecto usando Gemini AI
# =============================================================================

import os
import sys
import json
from pathlib import Path
from google import genai
from google.genai import types

# ============================================
# CONFIGURACIÓN
# ============================================

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
if not GEMINI_API_KEY:
    print(json.dumps({"error": "GEMINI_API_KEY no está configurada"}))
    sys.exit(1)

# Crear cliente con la API Key
client = genai.Client(api_key=GEMINI_API_KEY)

# ============================================
# RECOLECTAR CONTEXTO DEL PROYECTO
# ============================================

def recolectar_archivos_clave():
    """Recolecta archivos importantes del proyecto"""
    archivos_contexto = {}
    
    # Leer go.mod
    if Path("go.mod").exists():
        with open("go.mod", "r", encoding="utf-8") as f:
            archivos_contexto["go.mod"] = f.read()
    
    # Leer Dockerfile (IMPORTANTE: usa el Dockerfile real del proyecto)
    if Path("Dockerfile").exists():
        with open("Dockerfile", "r", encoding="utf-8") as f:
            archivos_contexto["Dockerfile"] = f.read()
    
    # Leer Makefile si existe
    if Path("Makefile").exists():
        with open("Makefile", "r", encoding="utf-8") as f:
            archivos_contexto["Makefile"] = f.read()
    
    # Leer README.md si existe
    if Path("README.md").exists():
        with open("README.md", "r", encoding="utf-8") as f:
            archivos_contexto["README.md"] = f.read()[:2000]  # Primeros 2000 chars
    
    # Buscar archivos .proto
    proto_files = list(Path("proto").rglob("*.proto")) if Path("proto").exists() else []
    for proto in proto_files[:5]:  # Limitar a 5 archivos
        with open(proto, "r", encoding="utf-8") as f:
            archivos_contexto[str(proto)] = f.read()
    
    # Buscar module.go en x/
    x_path = Path("x")
    if x_path.exists():
        for module_go in x_path.rglob("module.go"):
            with open(module_go, "r", encoding="utf-8") as f:
                archivos_contexto[str(module_go)] = f.read()
    
    return archivos_contexto

# ============================================
# PROMPT PARA GEMINI
# ============================================

def crear_prompt(contexto):
    """Crea el prompt para Gemini basado en el contexto"""
    contexto_formateado = "\n\n".join([
        f"### {archivo}\n```\n{contenido[:1000]}\n```" 
        for archivo, contenido in contexto.items()
    ])
    
    return f"""
Eres PrometeoDEV, un arquitecto experto en blockchain y escritor técnico especializado en Cosmos SDK y rollups modulares.

Tu misión es generar documentación profesional en formato Markdown para este proyecto blockchain basado en Cosmos SDK y Celestia.

**CONTEXTO DEL PROYECTO:**
{contexto_formateado}

**INSTRUCCIONES:**
Genera un documento técnico completo con estas secciones:

## 1. 🚀 Resumen del Proyecto
- Descripción concisa del propósito de la blockchain
- Arquitectura general (Cosmos SDK + Celestia DA)
- Propuesta de valor única

## 2. 🏗️ Arquitectura Técnica
- Stack tecnológico
- Integración con Celestia como DA layer
- Componentes principales

## 3. 📦 Módulos Principales
Lista de módulos personalizados encontrados en `x/`, explicando:
- Propósito de cada módulo
- Funcionalidad clave
- Mensajes principales

## 4. 🔌 API y Protobuf
Resumen de los servicios RPC y mensajes más importantes definidos en `.proto`:
- Queries principales
- Transacciones (Msgs)
- Eventos

## 5. 🔗 Dependencias Clave
Menciona dependencias críticas de `go.mod`:
- Cosmos SDK (versión)
- CometBFT
- IBC
- Celestia-specific dependencies

## 6. 🐳 Configuración Docker
Basado en el `Dockerfile` del proyecto:
- Imagen base utilizada
- Arquitectura multi-stage (si aplica)
- Puertos expuestos
- Volúmenes configurados
- Variables de entorno importantes

## 7. 🚀 Quick Start
Pasos básicos para:
- Compilar el nodo (con make o go build)
- Construir imagen Docker
- Inicializar una red local
- Ejecutar transacciones básicas

## 8. 🔐 Seguridad y Consideraciones
- Aspectos de seguridad
- No-determinismo
- Validación de mensajes

**FORMATO:**
- Usa Markdown profesional
- Incluye emojis para mejorar legibilidad
- Sé técnico pero accesible
- Incluye ejemplos de código cuando sea relevante
- Máximo 2000 palabras
"""

# ============================================
# GENERAR DOCUMENTACIÓN
# ============================================

def generar_documentacion():
    """Genera la documentación usando Gemini"""
    try:
        print("📝 Recolectando contexto del proyecto...")
        contexto = recolectar_archivos_clave()
        
        if not contexto:
            print("⚠️  No se encontraron archivos de contexto")
            return
        
        print(f"✅ Encontrados {len(contexto)} archivos de contexto")
        print("🤖 Generando documentación con Gemini...")
        
        prompt = crear_prompt(contexto)
        
        # Llamar a Gemini
        response = client.models.generate_content(
            model="gemini-2.0-flash-001",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.3,
                max_output_tokens=4096,
            )
        )
        
        # Guardar resultado
        doc_path = "DOCUMENTACION_PROYECTO.md"
        with open(doc_path, "w", encoding="utf-8") as f:
            f.write(response.text)
        
        print(f"✅ Documentación generada en {doc_path}")
        print(f"📊 Caracteres generados: {len(response.text)}")
        
    except Exception as e:
        print(json.dumps({
            "error": f"Error al generar documentación: {str(e)}",
            "type": type(e).__name__
        }))
        sys.exit(1)

if __name__ == "__main__":
    generar_documentacion()
