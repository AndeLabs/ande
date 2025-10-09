# AndeChain - Sovereign EVM Rollup Infrastructure

<div align="center">

**Blockchain Infrastructure for Latin America**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue.svg)](https://soliditylang.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)

</div>

---

## 🎯 ¿Qué es AndeChain?

**AndeChain es una rollup EVM soberana construida sobre Celestia, diseñada para resolver los desafíos financieros de América Latina.** Nuestra misión es proporcionar una infraestructura blockchain de bajo costo, alta velocidad y totalmente personalizable para potenciar la próxima generación de aplicaciones DeFi y Web3 en la región.

### Arquitectura Simplificada

```
📱 DApps & Wallets  ───(RPC)───> 🚀 AndeChain Rollup (EVM) ───(DA)───> 📊 Celestia
```

---

## 🚀 Getting Started (Para Desarrolladores)

Levanta un entorno de desarrollo local completo con un solo comando.

```bash
# 1. Clona el repositorio
git clone https://github.com/AndeLabs/andechain.git
cd andechain

# 2. Inicia todo el ecosistema
make start
```

Una vez completado, tu red local estará disponible en `http://localhost:8545`.

> Para una guía detallada sobre la configuración, el desarrollo, la arquitectura y la solución de problemas, consulta nuestro manual principal:
> **[📖 Manual de Onboarding y Operaciones](./docs/ONBOARDING.md)**

---

## 📚 Documentación Principal

Este repositorio contiene una rica documentación. Usa esta tabla como tu guía para encontrar lo que necesitas.

| Documento | Descripción |
| :--- | :--- |
| 📖 **[Manual de Onboarding](./docs/ONBOARDING.md)** | **EMPIEZA AQUÍ.** Tu guía completa para la instalación, desarrollo local, arquitectura y comandos. |
| 🗺️ **[Plan Maestro del Proyecto](./docs/AndeChainPlanMaestro.md)** | La visión estratégica, la hoja de ruta técnica y los objetivos a largo plazo del proyecto. |
| 🏛️ **[Arquitectura Técnica Detallada](./docs/ABOB_TECHNICAL_ARCHITECTURE.md)** | Un análisis profundo de la arquitectura del protocolo, el modelo CDP y los componentes core. |
| 🌉 **[Mecanismos de Seguridad del Puente](./docs/BRIDGE_ESCAPE_HATCHES.md)** | Documentación de seguridad crítica sobre los mecanismos de escape y seguridad del puente. |
| 🗳️ **[Modelo veANDE](./docs/VEANDE_MODEL.md)** | Explicación detallada de la tokenómica de voto-depositado (vote-escrow) y el modelo de gobernanza. |

---

## 🏗️ Componentes del Ecosistema

El monorepo está organizado en los siguientes componentes principales:

| Componente | Descripción |
| :--- | :--- |
| 📁 **[contracts](./contracts/)** | Contiene todos los contratos inteligentes del ecosistema (Tokens, Gobernanza, Puentes), gestionados con Foundry. |
| 📁 **[infra](./infra/)** | Entorno basado en Docker que orquesta la pila de desarrollo local (EVM, Sequencer, DA, Blockscout). |
| 📁 **[relayer](./relayer/)** | Servicio de retransmisión (TypeScript) responsable de tareas off-chain, como la comunicación del puente. |

---

## 🤝 Contribuciones

¡Las contribuciones son bienvenidas! Nos esforzamos por mantener un proceso de desarrollo limpio y colaborativo.

Antes de comenzar, por favor revisa nuestra **[guía de flujo de trabajo de Git y estándares de commit](./docs/ONBOARDING.md#-control-de-versiones-y-flujo-de-trabajo)** en el manual de onboarding.

Para más detalles, consulta nuestro archivo `CONTRIBUTING.md`.

---

## 🌐 Comunidad y Soporte

- **💬 Discord**: [Únete a nuestra comunidad](https://discord.gg/andechain)
- **🐙 GitHub**: [Explora el código](https://github.com/AndeLabs/andechain)
- **🐛 Reportar un Bug**: [Crear un Issue](https://github.com/AndeLabs/andechain/issues)

<div align="center">

**🚀 Construyendo la infraestructura financiera soberana de América Latina.**

</div>
