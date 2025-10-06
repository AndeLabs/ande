# 🏗️ ABOB 2.0 - Arquitectura Técnica Detallada
**Protocolo de Deuda Colateralizada (CDP) Multi-Activo**

---

## 📋 Tabla de Contenidos

1. [Resumen del Sistema](#resumen-del-sistema)
2. [Arquitectura de Contratos](#arquitectura-de-contratos)
3. [El Modelo de Vaults (CDP)](#el-modelo-de-vaults-cdp)
4. [Sistema de Oráculos (Medianizer)](#sistema-de-oráculos-medianizer)
5. [Sistema de Liquidación (Subastas)](#sistema-de-liquidación-subastas)
6. [Gobernanza (veANDE)](#gobernanza-veande)
7. [Flujos de Usuario](#flujos-de-usuario)

---

## 1. Resumen del Sistema

### Evolución del Concepto
ABOB ha evolucionado de una simple stablecoin híbrida a un sofisticado **Protocolo de Deuda Colateralizada (CDP)**. Este modelo, inspirado en los líderes de la industria como MakerDAO, permite a los usuarios acuñar (tomar prestado) ABOB contra un colateral que ellos mismos depositan en bóvedas personales y seguras (`Vaults`).

### Principios de Diseño de ABOB 2.0

- **Seguridad a través de Sobre-colateralización:** Todo ABOB en circulación está respaldado por un valor mayor de activos, creando un sistema resiliente a la volatilidad.
- **Flexibilidad Multi-Colateral:** El protocolo no está atado a un solo tipo de colateral. La gobernanza puede aprobar una canasta diversa de activos (ej. `USDC`, `wETH`, `ANDE`), minimizando el riesgo.
- **Justicia y Eficiencia:** Las liquidaciones se manejan a través de subastas, asegurando precios justos y devolviendo el valor excedente a los dueños de los vaults.
- **Gobernanza Alineada:** El poder de decisión recae en los holders más comprometidos a largo plazo a través del modelo `veANDE`.

```
┌───────────────────────────────────────────────────────────┐
│               ARQUITECTURA CDP - ABOB 2.0                   │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐             │
│  │   USDC   │   │   wETH   │   │   ANDE   │ (Colaterales) │
│  └─────┬────┘   └─────┬────┘   └─────┬────┘             │
│        └─────────────┬┴──────────────┘                  │
│                      ▼                                  │
│      ┌───────────────────────────┐                      │
│      │  Registro de Colaterales  │ (Gestionado por Gov.)  │
│      └─────────────┬─────────────┘                      │
│                    ▼                                    │
│      ┌───────────────────────────┐                      │
│      │  AbobToken (User Vaults)  │                      │
│      │  - Ratio Sobre-Colat: 150%  │                      │
│      └─────────────┬─────────────┘                      │
│                    │ Acuña (Pide prestado)              │
│                    ▼                                    │
│      ┌───────────────────────────┐                      │
│      │       Token ABOB          │ (Deuda del usuario)    │
│      └───────────────────────────┘                      │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## 2. Arquitectura de Contratos

El sistema se descompone en varios contratos modulares e interconectados:

| Contrato | Propósito | Patrón Clave |
| :--- | :--- | :--- |
| **`AbobToken.sol`** | Contrato principal que gestiona los Vaults de usuario, la acuñación y quema de ABOB. | ERC20, UUPS, ReentrancyGuard |
| **`CollateralManager.sol`** | Registro de los tipos de colateral aceptados y sus parámetros de riesgo. | Ownable/AccessControl |
| **`PriceOracle.sol`** | Agrega precios de múltiples fuentes para calcular una mediana segura. | Medianizer, AccessControl |
| **`AuctionManager.sol`** | Gestiona las subastas holandesas para liquidar colateral de vaults en riesgo. | Dutch Auction, ReentrancyGuard |
| **`Governance.sol`** | Controla todos los parámetros del sistema a través de propuestas y votaciones. | Governor, Timelock |
| **`veANDE.sol`** | Contrato de Vote-Escrow que gestiona el poder de voto de los usuarios. | ERC20, VotingEscrow |
| **`sABOB.sol`** | Vault de rendimiento (ERC4626) que acumula los ingresos del protocolo. | ERC4626 |

---

## 3. El Modelo de Vaults (CDP)

El contrato `AbobToken.sol` es el núcleo del sistema.

#### State Variables Clave

```solidity
// En CollateralManager.sol
struct CollateralInfo {
    bool isSupported;
    uint256 overCollateralizationRatio; // ej: 15000 = 150%
    uint256 liquidationThreshold;       // ej: 12500 = 125%
    uint256 liquidationBonus;         // ej: 500 = 5%
    address priceFeed;                // Dirección del oráculo para este activo
}
mapping(address => CollateralInfo) public collateralSettings;

// En AbobToken.sol
struct UserVault {
    mapping(address => uint256) collateralBalances; // Colateral por tipo
    uint256 totalDebt; // Total de ABOB acuñado
}
mapping(address => UserVault) public vaults;
```

#### Flujo de Acuñación (Mint)

1.  **`depositAndMint(address[] calldata _collaterals, uint256[] calldata _amounts, uint256 _abobToMint)`**
2.  **Verificar Colaterales:** El contrato consulta al `CollateralManager` para asegurarse de que todos los activos depositados son soportados.
3.  **Valorar Colateral:** Itera sobre los depósitos, llama al `PriceOracle` para obtener el valor en USD de cada uno y suma el valor total.
4.  **Verificar Sobre-colateralización:** Calcula el valor total de la deuda (`_abobToMint`) y lo compara con el valor del colateral. La siguiente condición debe cumplirse:
    `valorColateral >= valorDeuda * ratioSobreColateralizacion`
5.  **Transferir Fondos:** El contrato utiliza `transferFrom` para mover los colaterales desde el usuario a la custodia del contrato `AbobToken`.
6.  **Actualizar Vault:** Se actualiza el `UserVault` del usuario con los nuevos balances de colateral y la nueva deuda.
7.  **Acuñar ABOB:** Finalmente, se acuña la cantidad solicitada de `ABOB` a la dirección del usuario.

---

## 4. Sistema de Oráculos (Medianizer)

Para evitar la manipulación de precios, no confiamos en una sola fuente.

#### Arquitectura del `PriceOracle.sol`

1.  **Fuentes Múltiples:** Para cada activo (ej. `ANDE/USD`), la gobernanza registra múltiples direcciones de oráculos (ej. Chainlink, Pyth, P2POracle).
2.  **Reporte de Precios:** Los oráculos autorizados (o cualquiera, en un modelo abierto) reportan precios al contrato.
3.  **Cálculo de la Mediana:** En lugar de un promedio, el contrato ordena los precios reportados y elige el valor del medio. Esto es inmune a valores atípicos extremos.
4.  **Validación de Frescura:** El contrato se asegura de que los precios no sean demasiado antiguos (ej. más de 1 hora) antes de considerarlos válidos.

**Ventaja:** Un atacante necesitaría comprometer a más de la mitad de las fuentes de precios para manipular el precio final, un vector de ataque mucho más costoso y difícil.

---

## 5. Sistema de Liquidación (Subastas)

Cuando el valor del colateral de un usuario cae peligrosamente cerca del valor de su deuda, se activa la liquidación para mantener la solvencia del protocolo.

#### Arquitectura del `AuctionManager.sol`

1.  **Identificación de Vaults en Riesgo:** Un bot externo (o cualquier usuario) monitorea los vaults. Si `valorColateral / valorDeuda < umbralDeLiquidacion` (ej. 125%), puede iniciar la liquidación.
2.  **Inicio de Subasta Holandesa:**
    *   El `AuctionManager` toma control del colateral del vault en riesgo.
    *   Inicia una subasta pública donde el precio del colateral comienza alto (ej. precio de mercado) y disminuye linealmente con el tiempo.
3.  **Puja (Bid):**
    *   El primer postor que esté dispuesto a pagar el precio actual puede comprar una porción (o la totalidad) del colateral.
    *   El postor paga en `ABOB`.
4.  **Cierre de la Subasta:**
    *   El `ABOB` recibido se quema para pagar la deuda del vault.
    *   Se aplica una penalización de liquidación (ej. 5%), que se envía al tesoro del protocolo.
    *   **Crucial:** Si queda algún colateral después de pagar la deuda y la penalización, se devuelve al dueño original del vault.

**Ventaja:** Este sistema es más justo para el usuario y más eficiente para el protocolo, ya que el mercado descubre el precio real del colateral en lugar de ofrecer un descuento fijo a un solo liquidador.

---

## 6. Gobernanza (veANDE)

Para alinear los incentivos con el éxito a largo plazo, el poder de voto no es directamente proporcional al balance de `ANDE`.

#### Arquitectura de `veANDE.sol`

1.  **Bloqueo de Tokens:** Los usuarios bloquean sus `ANDE` en el contrato `veANDE` por un período determinado (ej. 1 mes a 4 años).
2.  **Asignación de Poder de Voto:** Reciben `veANDE` (un token no transferible) en proporción tanto a la **cantidad** de `ANDE` bloqueados como al **tiempo** de bloqueo.
    *   `1000 ANDE por 4 años = 1000 veANDE`
    *   `1000 ANDE por 1 año = 250 veANDE`
3.  **Decaimiento Lineal:** El poder de voto (`veANDE`) disminuye linealmente a medida que se acerca el final del período de bloqueo, hasta llegar a cero.
4.  **Uso en Gobernanza:** El balance de `veANDE` de un usuario es lo que se utiliza para proponer y votar en el `Governance.sol`.

**Ventaja:** Otorga más poder a los holders más comprometidos, haciendo al protocolo resistente a la manipulación por parte de especuladores a corto plazo.

---

## 7. Flujos de Usuario

#### Flujo de Acuñación de ABOB

```
Usuario (con USDC y ANDE)
    │
    ├─ 1. Llama a `approve()` en USDC y ANDE para autorizar al AbobToken
    │
    ▼
AbobToken.sol
    ├─ 2. Llama a `depositAndMint(usdcAmount, andeAmount, abobToMint)`
    │      ├─ Consulta a CollateralManager si los activos son válidos
    │      ├─ Consulta a PriceOracle el valor de USDC y ANDE
    │      ├─ Valida que (valor USDC + valor ANDE) >= (valor ABOB * 150%)
    │      ├─ Llama a `transferFrom()` en USDC y ANDE
    │      ├─ Actualiza el UserVault del usuario
    │      └─ Llama a `_mint()` para crear ABOB para el usuario
    │
    ▼
Usuario recibe ABOB
```

#### Flujo de Liquidación

```
Bot Liquidador
    │
    ├─ 1. Monitorea `getCollateralizationRatio(user)` para todos los vaults
    │
    ▼
AbobToken.sol
    ├─ 2. Si ratio < 125%, el bot llama a `AuctionManager.startAuction(user)`
    │
    ▼
AuctionManager.sol
    ├─ 3. Inicia subasta holandesa del colateral del `user`
    │
    ▼
Postor (Bidder)
    ├─ 4. Ve un precio atractivo y llama a `bid(auctionId, amount)` pagando con ABOB
    │
    ▼
AuctionManager.sol
    ├─ 5. Transfiere colateral al postor
    ├─ 6. Quema el ABOB recibido para pagar la deuda
    ├─ 7. Envía penalización al Tesoro
    └─ 8. Devuelve el colateral sobrante (si lo hay) al dueño original del vault
```
