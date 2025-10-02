# 🏔️ AndeChain - Un Rollup Soberano para LATAM

## 🌟 Visión

AndeChain es una blockchain soberana regional que inicia en Bolivia y se expande, construida como un **Rollup EVM sobre Celestia**. Nuestra misión es resolver la fragmentación financiera de América Latina a través de un sistema económico robusto y una infraestructura tecnológica de vanguardia.

Para una inmersión profunda en la visión y el modelo económico, consulta nuestro plan maestro: [**planande.md**](planande.md).

## 🏗️ Arquitectura Técnica

Nuestro stack tecnológico está completamente contenedorizado con Docker y se compone de tres capas principales:

1.  **Capa de Ejecución (EVM):** Utilizamos **Reth**, un cliente de ejecución de Ethereum de alto rendimiento, para procesar transacciones y ejecutar smart contracts en Solidity.
2.  **Capa de Secuenciación:** Usamos **Evolve (ev-node)**, basado en Rollkit, para ordenar transacciones, producir bloques y publicarlos en la capa de disponibilidad de datos.
3.  **Capa de Disponibilidad de Datos (DA):** Nos apoyamos en **Celestia** para garantizar que los datos de las transacciones sean públicos, verificables y seguros.

## 🚀 Guía de Inicio Rápido (Desarrollo Local)

Levantar un entorno de desarrollo completo de AndeChain es un proceso sencillo gracias a Docker.

**Requisitos:**
- Docker Desktop
- Node.js y npm

**Pasos:**

1.  **Clona el repositorio:**
    ```bash
    git clone https://github.com/AndeLabs/ande.git
    cd ande/andechain
    ```

2.  **Configura el entorno:**
    Navega a la carpeta de infraestructura y crea tus archivos `.env` a partir de los ejemplos.
    ```bash
    cd infra
    cp .env.example .env
    cp stacks/eth-faucet/.env.example stacks/eth-faucet/.env
    # ¡No olvides añadir tus llaves privadas al archivo .env!
    ```

3.  **Lanza el Stack:**
    Este comando levantará todos los servicios (Reth, Evolve, DA local, Explorador, Faucet) en segundo plano.
    ```bash
    docker compose up -d --build
    ```

¡Y listo! Tu rollup soberano local estará funcionando.

- **RPC Endpoint:** `http://localhost:8545`
- **Explorador de Bloques:** `http://localhost:4000`

## 🛠️ Flujo de Desarrollo y Pruebas

Todo el desarrollo y las pruebas de los smart contracts se gestionan a través de Docker para garantizar la consistencia.

- **Compilar Contratos:**
  ```bash
  docker compose run --build contracts npm run compile
  ```

- **Ejecutar Pruebas Unitarias y de Integración:**
  Utilizamos la red en memoria de Hardhat para pruebas rápidas y fiables.
  ```bash
  docker compose run --build contracts npm test
  ```

Para una guía detallada sobre el flujo de trabajo, la configuración avanzada y las lecciones aprendidas durante el desarrollo, consulta nuestro manual de incorporación: [**ONBOARDING.md**](ONBOARDING.md).

## 🤝 Cómo Contribuir

¡Estamos construyendo el futuro financiero de LATAM y tu ayuda es bienvenida! Antes de contribuir, por favor lee nuestra guía de flujo de trabajo de Git para entender cómo manejamos las ramas y los commits.

- [**Guía de Flujo de Trabajo de Git**](GIT_WORKFLOW.md)
