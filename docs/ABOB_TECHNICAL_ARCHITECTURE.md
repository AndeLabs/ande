# 🏗️ ABOB - Arquitectura Técnica Detallada
**Sistema de Stablecoin Híbrida Vinculada al Boliviano Boliviano**

---

## 📋 Tabla de Contenidos

1. [Resumen del Sistema](#resumen-del-sistema)
2. [Arquitectura de Contratos](#arquitectura-de-contratos)
3. [Mecanismo de Colateral Dual](#mecanismo-de-colateral-dual)
4. [Sistema de Oráculos](#sistema-de-oráculos)
5. [Yield Generation (sABOB)](#yield-generation-sabob)
6. [Flujos de Integración](#flujos-de-integración)
7. [Consideraciones de Seguridad](#consideraciones-de-seguridad)
8. [Ejemplos de Código](#ejemplos-de-código)

---

## Resumen del Sistema

### Problema que Resuelve ABOB

**Desafío:** Los bolivianos necesitan una stablecoin que:
- ✅ Mantenga paridad con el Boliviano (BOB) local
- ✅ Sea resistente a volatilidad de crypto
- ✅ Genere yield pasivo para ahorradores
- ✅ Permita transferencias cross-border baratas y rápidas
- ✅ Sea descentralizada y censorship-resistant

### Solución: Sistema Híbrido Triple

```
┌─────────────────────────────────────────────────────┐
│              ABOB TOKEN SYSTEM                      │
└─────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │  ABOB   │     │ sABOB   │     │ Bridge  │
   │ ERC20   │     │ ERC4626 │     │ xERC20  │
   └────┬────┘     └────┬────┘     └────┬────┘
        │                │                │
    Stability        Yield           Cross-chain
    Mechanism        Generation      Liquidity
        │                │                │
   ┌────▼────┐     ┌────▼────┐     ┌────▼────┐
   │ Dual    │     │ Protocol│     │ Rate    │
   │Collateral│     │ Revenue │     │ Limits  │
   └─────────┘     └─────────┘     └─────────┘
```

---

## Arquitectura de Contratos

### 1. AbobToken.sol - Núcleo del Sistema

**Ubicación:** `/contracts/src/AbobToken.sol`
**Patrón:** ERC20 Upgradeable (UUPS)
**Versión Solidity:** ^0.8.25

#### Herencia

```solidity
contract AbobToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuard
```

**Justificación de cada componente:**
- `Initializable`: Patrón proxy para upgradeability
- `ERC20Upgradeable`: Funcionalidad estándar de token
- `ERC20BurnableUpgradeable`: Permite quemar tokens en redeem
- `AccessControlUpgradeable`: Roles granulares (GOVERNANCE_ROLE, PAUSER_ROLE)
- `UUPSUpgradeable`: Upgrades controlados por gobernanza
- `PausableUpgradeable`: Emergency stop en caso de ataque
- `ReentrancyGuard`: Protección contra reentrancy en mint/redeem

---

#### State Variables Clave

```solidity
// Tokens de colateral
IERC20 public ausdToken;     // Componente estable (USD-pegged)
IERC20 public andeToken;     // Componente volátil (governance token)

// Oráculos de precio
IOracle public andePriceFeed;  // Precio ANDE/USD
IOracle public abobPriceFeed;  // Precio ABOB/BOB (target peg)

// Ratio de colateralización
uint256 public collateralRatio;       // En basis points (10000 = 100%)
uint256 public constant BASIS_POINTS = 10000;
```

**Ejemplo de configuración:**
```solidity
collateralRatio = 7000;  // 70% AUSD, 30% ANDE

Para mint 100 ABOB (asumiendo 1 ABOB = 1 BOB = 0.14 USD):
- Valor total: 100 ABOB × 0.14 USD = 14 USD
- AUSD requerido: 14 USD × 70% = 9.8 AUSD
- ANDE requerido: 14 USD × 30% = 4.2 USD worth of ANDE

Si ANDE = $0.50:
- ANDE tokens requeridos: 4.2 / 0.50 = 8.4 ANDE
```

---

#### Función Mint - Análisis Detallado

```solidity
function mint(uint256 _abobAmountToMint) external whenNotPaused nonReentrant {
    require(_abobAmountToMint > 0, "Amount must be positive");

    // 1. Obtener precios de oráculos
    (, int256 andePriceSigned, , , ) = andePriceFeed.latestRoundData();
    (, int256 abobPriceSigned, , , ) = abobPriceFeed.latestRoundData();
    require(andePriceSigned > 0 && abobPriceSigned > 0, "Invalid oracle price");

    uint256 andePrice = uint256(andePriceSigned);
    uint256 abobPrice = uint256(abobPriceSigned);

    // 2. Calcular valor total del colateral en USD
    uint256 totalCollateralValueInUSD = Math.mulDiv(
        _abobAmountToMint,
        abobPrice,
        1e18
    );

    // 3. Calcular AUSD requerido (porción estable)
    uint256 requiredAusdAmount = Math.mulDiv(
        totalCollateralValueInUSD,
        collateralRatio,
        BASIS_POINTS
    );

    // 4. Calcular ANDE requerido (porción algorítmica)
    uint256 requiredAndeValueInUSD = totalCollateralValueInUSD - requiredAusdAmount;
    uint256 requiredAndeAmount = Math.mulDiv(
        requiredAndeValueInUSD,
        1e18,
        andePrice
    );

    // 5. Transferir colaterales desde el usuario
    ausdToken.safeTransferFrom(msg.sender, address(this), requiredAusdAmount);
    andeToken.safeTransferFrom(msg.sender, address(this), requiredAndeAmount);

    // 6. Mint ABOB al usuario
    _mint(msg.sender, _abobAmountToMint);

    emit Minted(msg.sender, _abobAmountToMint, requiredAusdAmount, requiredAndeAmount);
}
```

**Seguridad Implementada:**
- ✅ `nonReentrant`: Previene ataques de reentrancy
- ✅ `whenNotPaused`: Permite emergency stop
- ✅ `Math.mulDiv`: Previene overflow/underflow
- ✅ `safeTransferFrom`: Maneja tokens no-estándar correctamente
- ✅ Oracle validation: Verifica precios positivos

**Posibles Mejoras Futuras:**
- [ ] Slippage protection (max price deviation)
- [ ] Minimum mint amount (prevenir dust attacks)
- [ ] Cooldown period entre mint/redeem (prevenir arbitrage flash loans)
- [ ] Fee mechanism (pequeño % del mint va a treasury)

---

#### Función Redeem - Análisis Detallado

```solidity
function redeem(uint256 _abobAmountToBurn) external whenNotPaused nonReentrant {
    require(_abobAmountToBurn > 0, "Amount must be positive");

    // 1. Quemar ABOB del usuario PRIMERO (checks-effects-interactions)
    _burn(msg.sender, _abobAmountToBurn);

    // 2. Obtener precios actuales
    (, int256 andePriceSigned, , , ) = andePriceFeed.latestRoundData();
    (, int256 abobPriceSigned, , , ) = abobPriceFeed.latestRoundData();
    require(andePriceSigned > 0 && abobPriceSigned > 0, "Invalid oracle price");

    uint256 andePrice = uint256(andePriceSigned);
    uint256 abobPrice = uint256(abobPriceSigned);

    // 3. Calcular valor del colateral a devolver
    uint256 totalCollateralValueInUSD = Math.mulDiv(
        _abobAmountToBurn,
        abobPrice,
        1e18
    );

    // 4. Calcular AUSD a devolver
    uint256 ausdAmountToReturn = Math.mulDiv(
        totalCollateralValueInUSD,
        collateralRatio,
        BASIS_POINTS
    );

    // 5. Calcular ANDE a devolver
    uint256 andeValueToReturnInUSD = totalCollateralValueInUSD - ausdAmountToReturn;
    uint256 andeAmountToReturn = Math.mulDiv(
        andeValueToReturnInUSD,
        1e18,
        andePrice
    );

    // 6. Transferir colaterales al usuario
    ausdToken.safeTransfer(msg.sender, ausdAmountToReturn);
    andeToken.safeTransfer(msg.sender, andeAmountToReturn);

    emit Redeemed(msg.sender, _abobAmountToBurn, ausdAmountToReturn, andeAmountToReturn);
}
```

**Patrón Checks-Effects-Interactions:**
1. ✅ **Checks:** Validar amount > 0, pausado, etc.
2. ✅ **Effects:** `_burn()` ANTES de transferencias
3. ✅ **Interactions:** Transferencias externas AL FINAL

**Riesgo Mitigado:**
Si un token malicioso tuviera hook en transfer, no podría re-entrar porque el burn ya ocurrió.

---

### 2. sAbobToken.sol - Yield-Bearing Vault

**Ubicación:** `/contracts/src/sAbobToken.sol`
**Patrón:** ERC-4626 Tokenized Vault
**Estándar:** https://eips.ethereum.org/EIPS/eip-4626

#### Concepto ERC-4626

ERC-4626 es un estándar para vaults que:
- Tiene un **asset** subyacente (en nuestro caso: ABOB)
- Emite **shares** que representan ownership del vault (sABOB)
- El valor de shares aumenta con el tiempo según yield acumulado

**Fórmula de conversión:**
```
shares = assets × totalSupply() / totalAssets()

Si vault tiene:
- 1000 ABOB depositados (totalAssets)
- 900 sABOB emitidos (totalSupply)

Depositar 100 ABOB:
shares = 100 × 900 / 1000 = 90 sABOB

Luego de acumular 100 ABOB de yield:
- totalAssets = 1100 ABOB
- totalSupply = 990 sABOB

Redeem 90 sABOB:
assets = 90 × 1100 / 990 = 100 ABOB

¡El usuario recupera 100 ABOB por 90 sABOB! (ganancia del yield)
```

---

#### Implementación Específica

```solidity
contract sAbobToken is
    Initializable,
    ERC4626Upgradeable,      // Vault logic
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable
{
    bytes32 public constant YIELD_DEPOSITOR_ROLE = keccak256("YIELD_DEPOSITOR_ROLE");

    function depositYield(uint256 amount)
        external
        onlyRole(YIELD_DEPOSITOR_ROLE)
    {
        require(amount > 0, "Yield amount must be positive");
        // Transfer ABOB from depositor (revenue contracts)
        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);
        // No minting needed - just increases totalAssets()
        // This automatically increases share value!
    }
}
```

#### Fuentes de Yield para sABOB

```
┌─────────────────────────────────────────────┐
│         REVENUE SOURCES → sABOB             │
└─────────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┐
    │               │               │
┌───▼───┐      ┌───▼───┐      ┌───▼───┐
│ DEX   │      │Bridge │      │Lending│
│ Fees  │      │ Fees  │      │Interest│
└───┬───┘      └───┬───┘      └───┬───┘
    │               │               │
    └───────────────┼───────────────┘
                    │
                    ▼
        depositYield() to sABOB vault
                    │
                    ▼
        Share value increases automatically
```

**Contratos que depositarán yield:**
- `AndeDEX.sol` (futuro): % de swap fees
- `AndeLending.sol` (futuro): % de interest
- `AndeChainBridge.sol`: % de bridge fees
- `Treasury.sol`: % de protocol revenue

**Ejemplo de integración en DEX:**
```solidity
// En AndeDEX.sol (futuro)
function _collectFees(uint256 fee) internal {
    uint256 yieldShare = fee * SABOB_YIELD_PERCENTAGE / 10000;

    // Approve sABOB vault
    abobToken.approve(address(sAbobVault), yieldShare);

    // Deposit yield
    sAbobVault.depositYield(yieldShare);
}
```

---

### 3. AusdToken.sol - Componente Estable

**Ubicación:** `/contracts/src/AusdToken.sol`
**Propósito:** Stablecoin USD colateralizada que sirve como componente estable de ABOB

#### Multi-Collateral Vault Architecture

```solidity
struct CollateralInfo {
    bool isSupported;
    uint128 overCollateralizationRatio;  // Ejemplo: 15000 = 150%
    IOracle priceFeed;                   // Oracle de precio USD
    uint256 totalDeposited;              // Tracking de colateral
}

mapping(address => CollateralInfo) public collateralTypes;
```

**Colaterales soportados (configurables):**
```
USDC → Ratio 110% → Chainlink oracle
USDT → Ratio 110% → Chainlink oracle
DAI  → Ratio 120% → Chainlink oracle
WETH → Ratio 150% → Chainlink oracle
WBTC → Ratio 150% → Chainlink oracle
```

#### Flujo de Mint AUSD

```solidity
function depositAndMint(address _collateral, uint256 _collateralAmount)
    external
    whenNotPaused
    nonReentrant
{
    // 1. Validaciones
    if (_collateralAmount == 0) revert AmountMustBePositive();
    CollateralInfo storage collateral = collateralTypes[_collateral];
    if (!collateral.isSupported) revert CollateralNotSupported();

    // 2. Obtener precio del colateral
    (, int256 price_signed, , , ) = collateral.priceFeed.latestRoundData();
    if (price_signed <= 0) revert OraclePriceInvalid();
    uint256 collateralPrice = uint256(price_signed);
    uint8 oracleDecimals = collateral.priceFeed.decimals();

    // 3. Calcular valor en USD
    uint8 collateralDecimals = IERC20withDecimals(_collateral).decimals();
    uint256 scaledPrice = collateralPrice * (10**(18 - oracleDecimals));
    uint256 valueInUsd = Math.mulDiv(
        _collateralAmount,
        scaledPrice,
        (10**collateralDecimals)
    );

    // 4. Aplicar over-collateralization ratio
    uint256 amountToMint = Math.mulDiv(
        valueInUsd,
        10000,
        collateral.overCollateralizationRatio
    );

    // 5. Transfer y mint
    IERC20(_collateral).safeTransferFrom(msg.sender, address(this), _collateralAmount);
    collateral.totalDeposited += _collateralAmount;
    _mint(msg.sender, amountToMint);

    emit Minted(msg.sender, _collateral, _collateralAmount, amountToMint);
}
```

**Ejemplo Numérico:**
```
Usuario deposita 150 USDC (decimals = 6)
USDC price = $1.00 (oracle decimals = 8)
Ratio = 150% (15000 basis points)

Cálculos:
1. scaledPrice = 1e8 × 10^(18-8) = 1e18
2. valueInUsd = (150 × 1e6) × 1e18 / 1e6 = 150e18
3. amountToMint = 150e18 × 10000 / 15000 = 100e18

Usuario recibe 100 AUSD por 150 USDC depositados
```

---

## Mecanismo de Colateral Dual

### ¿Por qué Colateral Dual?

**Problema de stablecoins algorítmicas puras:**
- Terra/LUNA colapsó porque 100% algorítmico
- No hay respaldo real en momentos de stress

**Problema de stablecoins 100% colateralizadas:**
- Capital ineficiente (necesitas depositar >100% para mint)
- Centralización (USDC, USDT dependen de custodios)

**Solución: Híbrido 70/30**
```
ABOB Collateral = 70% AUSD + 30% ANDE

Ventajas:
✅ AUSD proporciona estabilidad (respaldado por USDC/USDT real)
✅ ANDE proporciona eficiencia de capital
✅ ANDE alinea incentivos (holders de ANDE quieren que ABOB tenga éxito)
✅ Gobernanza puede ajustar ratio según condiciones de mercado
```

### Dinámica del Ratio

**Ratio ajustable por gobernanza basado en:**

**Mercado Alcista (ANDE subiendo):**
```
Puede reducir componente AUSD: 60/40 o 50/50
→ Menos dependencia de stablecoins centralizadas
→ Mayor eficiencia de capital
→ Más exposición al upside de ANDE
```

**Mercado Bajista (ANDE cayendo):**
```
Aumentar componente AUSD: 80/20 o 90/10
→ Mayor estabilidad
→ Menor riesgo de liquidaciones
→ Protección contra volatilidad
```

**Propuesta de Gobernanza Ejemplo:**
```solidity
// En Governor contract (futuro)
function propose_AdjustCollateralRatio(uint256 newRatio) external {
    // newRatio = 8000 (80% AUSD, 20% ANDE)

    require(newRatio >= 5000 && newRatio <= 9500, "Ratio must be 50-95%");

    // Crear propuesta de gobernanza
    // Votación de holders de veANDE
    // Timelock de 7 días
    // Ejecución: abobToken.setCollateralRatio(newRatio)
}
```

---

### Health Ratio del Sistema

**Métrica clave:** Ratio de colateralización real del sistema

```solidity
// View function para monitorear health
function getSystemHealthRatio() external view returns (uint256) {
    uint256 totalAbobSupply = totalSupply();

    // Valor del colateral AUSD
    uint256 ausdValue = ausdToken.balanceOf(address(this));

    // Valor del colateral ANDE
    (, int256 andePrice, , , ) = andePriceFeed.latestRoundData();
    uint256 andeValue = Math.mulDiv(
        andeToken.balanceOf(address(this)),
        uint256(andePrice),
        1e18
    );

    uint256 totalCollateralValue = ausdValue + andeValue;

    // Ratio real
    return Math.mulDiv(totalCollateralValue, 10000, totalAbobSupply);
}
```

**Ejemplo:**
```
ABOB Supply: 1,000,000 tokens
AUSD Collateral: 700,000 AUSD ($700k)
ANDE Collateral: 1,000,000 ANDE @ $0.30 = $300k

Total Collateral Value: $1,000,000
Health Ratio = 1,000,000 / 1,000,000 = 100% (1:1 backed)

Si ANDE cae a $0.20:
Total Collateral = $700k + $200k = $900k
Health Ratio = 900,000 / 1,000,000 = 90% (undercollateralized!)

→ Trigger emergency response:
  - Pausar nuevos mints
  - Aumentar collateralRatio para nuevos deposits
  - Insurance fund injection
  - Votación de gobernanza para acción correctiva
```

---

## Sistema de Oráculos

### P2POracleV2 - Arquitectura Descentralizada

**Ubicación:** `/contracts/src/P2POracleV2.sol`

#### Conceptos Clave

**1. Stake-to-Report:**
```solidity
function register() external nonReentrant {
    // Reporter debe stake minStake de ANDE tokens
    reporters[msg.sender] = Reporter({
        isRegistered: true,
        stake: minStake,
        registrationTime: block.timestamp,
        lastReportEpoch: 0
    });

    andeToken.safeTransferFrom(msg.sender, address(this), minStake);

    emit ReporterRegistered(msg.sender, minStake);
}
```

**2. Epoch-Based Reporting:**
```
Epoch Duration: 1 hour (3600 seconds)
Current Epoch = block.timestamp / 3600

Epoch 0: 0-3600 seconds (reporters submit prices)
Epoch 1: 3600-7200 seconds (reporters submit, epoch 0 finalized)
Epoch 2: 7200-10800 seconds (reporters submit, epoch 1 finalized)
```

**3. Stake-Weighted Median:**
```solidity
function finalizeCurrentEpoch() external onlyRole(FINALIZER_ROLE) {
    PriceReport[] memory reports = epochReports[currentEpoch];

    // Ordenar por precio
    _sortReports(reports);

    // Calcular stake total
    uint256 totalStake = 0;
    for (uint i = 0; i < reports.length; i++) {
        totalStake += reports[i].stake;
    }

    // Encontrar mediana ponderada
    uint256 medianStake = totalStake / 2;
    uint256 cumulativeStake = 0;

    for (uint i = 0; i < reports.length; i++) {
        cumulativeStake += reports[i].stake;
        if (cumulativeStake >= medianStake) {
            medianPrice = reports[i].price;
            break;
        }
    }

    finalizedPrices[currentEpoch] = medianPrice;
}
```

**Ejemplo Numérico:**
```
Epoch 100 - Precio ANDE/USD

Reporter A: stake 1000 ANDE, reporta $0.50
Reporter B: stake 500 ANDE,  reporta $0.48
Reporter C: stake 2000 ANDE, reporta $0.52
Reporter D: stake 500 ANDE,  reporta $0.45

Total stake = 4000 ANDE
Median stake = 2000 ANDE

Ordenado por precio:
1. D: $0.45, stake 500  (cumulative: 500)
2. B: $0.48, stake 500  (cumulative: 1000)
3. A: $0.50, stake 1000 (cumulative: 2000) ← MEDIAN!
4. C: $0.52, stake 2000 (cumulative: 4000)

Precio finalizado: $0.50

Ventaja: Reporter C tiene más stake pero no puede manipular
solo, necesitaría >50% del stake total.
```

---

#### Slashing Mechanism

```solidity
function slash(address reporterAddress) external onlyRole(SLASHER_ROLE) {
    Reporter storage reporter = reporters[reporterAddress];
    require(reporter.isRegistered, "Not a registered reporter");

    uint256 slashedAmount = reporter.stake;
    delete reporters[reporterAddress];

    // Stake slashed permanece en contrato (o va a insurance fund)

    emit ReporterSlashed(reporterAddress, slashedAmount);
}
```

**Casos de Slashing:**
1. Reportar precio fuera de rango razonable (>10% desviación)
2. No reportar en X epochs consecutivos
3. Evidencia de colusión con otros reporters
4. Manipulación probada del precio

**Propuesta Futura: Automatic Slashing**
```solidity
// En finalizeEpoch, detectar outliers
function _detectOutliers(PriceReport[] memory reports, uint256 medianPrice) {
    for (uint i = 0; i < reports.length; i++) {
        uint256 deviation = abs(reports[i].price - medianPrice);
        uint256 deviationPercent = deviation * 10000 / medianPrice;

        if (deviationPercent > OUTLIER_THRESHOLD) {  // ej: 1000 = 10%
            _slash(reports[i].reporter);
        }
    }
}
```

---

### Integration con Chainlink (Futuro)

**Hybrid Oracle Strategy:**
```solidity
contract HybridOracle is IOracle {
    P2POracleV2 public p2pOracle;
    AggregatorV3Interface public chainlinkOracle;

    uint256 public constant MAX_DEVIATION = 500; // 5%

    function latestRoundData() external view returns (...) {
        // Obtener ambos precios
        (, int256 p2pPrice, , , ) = p2pOracle.latestRoundData();
        (, int256 clPrice, , , ) = chainlinkOracle.latestRoundData();

        // Verificar desviación
        uint256 deviation = abs(p2pPrice - clPrice);
        uint256 deviationPercent = deviation * 10000 / uint256(clPrice);

        if (deviationPercent > MAX_DEVIATION) {
            // Precios divergen mucho, usar Chainlink (más confiable)
            return chainlinkOracle.latestRoundData();
        }

        // Precios consistentes, usar promedio
        int256 avgPrice = (p2pPrice + clPrice) / 2;
        return (..., avgPrice, ...);
    }
}
```

---

## Yield Generation (sABOB)

### Revenue Streams Detallados

#### 1. DEX Trading Fees

**Future Contract:** `AndeDEX.sol`

```solidity
contract AndeDEX {
    uint256 public constant TRADING_FEE = 30; // 0.30%
    uint256 public constant SABOB_ALLOCATION = 3000; // 30% of fees

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        // Execute swap logic
        amountOut = _calculateSwapOutput(tokenIn, tokenOut, amountIn);

        // Calculate fees
        uint256 feeAmount = Math.mulDiv(amountOut, TRADING_FEE, 10000);
        uint256 sAbobYield = Math.mulDiv(feeAmount, SABOB_ALLOCATION, 10000);

        // Convert fee to ABOB if needed
        if (tokenOut != address(abobToken)) {
            sAbobYield = _convertToAbob(tokenOut, sAbobYield);
        }

        // Deposit yield to sABOB vault
        abobToken.approve(address(sAbobVault), sAbobYield);
        sAbobVault.depositYield(sAbobYield);

        // Transfer final amount to user
        IERC20(tokenOut).transfer(msg.sender, amountOut - feeAmount);
    }
}
```

**Projected Revenue:**
```
Assumptions:
- $10M daily volume in ABOB pairs
- 0.30% fee
- 30% to sABOB vault

Daily revenue to sABOB: $10M × 0.003 × 0.30 = $9,000
Annual: $9,000 × 365 = $3.285M

If sABOB TVL = $20M:
APY = $3.285M / $20M = 16.4%
```

---

#### 2. Bridge Fees

**Current Contract:** `AndeChainBridge.sol`

```solidity
// Future enhancement
uint256 public bridgeFeePercent = 20; // 0.20%
uint256 public sAbobAllocation = 5000; // 50% of bridge fees

function bridgeTokens(...) external {
    // Current implementation
    IXERC20(token).burn(msg.sender, amount);

    // Add fee mechanism
    uint256 fee = Math.mulDiv(amount, bridgeFeePercent, 10000);
    uint256 sAbobYield = Math.mulDiv(fee, sAbobAllocation, 10000);

    // Deposit to sABOB vault
    abobToken.approve(address(sAbobVault), sAbobYield);
    sAbobVault.depositYield(sAbobYield);

    emit TokensBridged(token, msg.sender, recipient, amount - fee, destinationChain, nonce++);
}
```

---

#### 3. Lending Protocol Interest (Future)

**Future Contract:** `AndeLending.sol`

```solidity
contract AndeLending {
    // Users deposit ABOB
    // Borrowers pay interest
    // sABOB holders receive % of interest

    function repayBorrow(uint256 amount) external {
        // Repay logic
        uint256 interestPaid = _calculateInterest(msg.sender);

        // Allocate to sABOB
        uint256 sAbobShare = Math.mulDiv(interestPaid, 4000, 10000); // 40%

        sAbobVault.depositYield(sAbobShare);
    }
}
```

---

### sABOB APY Projections

**Conservative Scenario (Year 1):**
```
DEX Volume: $5M/day
Bridge Volume: $2M/day
Lending: Not launched

DEX Revenue: $5M × 0.003 × 0.30 × 365 = $1.64M
Bridge Revenue: $2M × 0.002 × 0.50 × 365 = $730k
Total Annual: $2.37M

sABOB TVL: $10M
APY: 23.7%
```

**Optimistic Scenario (Year 2):**
```
DEX Volume: $20M/day
Bridge Volume: $10M/day
Lending TVL: $30M @ 5% borrow rate

DEX Revenue: $6.57M
Bridge Revenue: $3.65M
Lending Revenue: $30M × 0.05 × 0.40 = $600k
Total Annual: $10.82M

sABOB TVL: $30M
APY: 36.1%
```

---

## Flujos de Integración

### Flujo Completo: Usuario Deposita y Gana Yield

```
PASO 1: Usuario adquiere ABOB
├─ Usuario tiene: 1000 USDC
├─ Mint 700 AUSD (deposita 1000 USDC @ 110% ratio)
├─ Compra 200 ANDE en DEX con 300 USDC
├─ Mint 1000 ABOB (deposita 700 AUSD + 200 ANDE @ ratio 70/30)
└─ Usuario ahora tiene: 1000 ABOB

PASO 2: Stake en sABOB
├─ Usuario deposita 1000 ABOB en sABOB vault
├─ Recibe 1000 sABOB (ratio 1:1 inicial)
└─ Empieza a acumular yield automáticamente

PASO 3: Yield Accrual (30 días después)
├─ Protocol genera $10k en fees
├─ $3k depositados en sABOB vault via depositYield()
├─ totalAssets() del vault aumenta
│   Antes: 100,000 ABOB
│   Después: 103,000 ABOB
└─ Share value aumenta automáticamente

PASO 4: Usuario Redeem (después de 1 año)
├─ Usuario tiene: 1000 sABOB
├─ Vault stats:
│   totalSupply: 100,000 sABOB
│   totalAssets: 140,000 ABOB (40% yield en el año)
├─ Redeem calculation:
│   assets = 1000 × 140,000 / 100,000 = 1400 ABOB
├─ Usuario recibe: 1400 ABOB
└─ Yield ganado: 400 ABOB ($56 @ $0.14/ABOB)
```

---

### Flujo de Bridge Cross-Chain

```
ESCENARIO: Usuario en Ethereum envía ABOB a Bolivia

ETHEREUM CHAIN:
├─ Usuario tiene: 1000 ABOB (xERC20 version)
├─ Usuario llama: bridge.bridgeTokens(ABOB, recipientAddress, 1000, ANDECHAIN_ID)
│   ├─ Bridge valida: supportedTokens[ABOB] = true
│   ├─ Bridge valida: destinationBridges[ANDECHAIN_ID] != 0
│   ├─ Bridge valida: rate limits de xERC20
│   │   Current limit: 10,000 ABOB/hour
│   │   Requested: 1,000 ABOB ✓
│   ├─ ABOB.burn(usuario, 1000) ✓
│   └─ emit TokensBridged(ABOB, usuario, recipientAddress, 1000, ANDECHAIN_ID, nonce)
└─ Transacción incluida en bloque Ethereum #12345

CELESTIA DA:
├─ Relayer detecta evento TokensBridged
├─ Batch de eventos enviado a Celestia
├─ Celestia genera Merkle proof del evento
└─ Proof disponible para queries

ANDECHAIN:
├─ Relayer llama: bridge.receiveTokens(
│       ABOB,
│       recipientAddress,
│       1000,
│       ETHEREUM_CHAIN_ID,
│       ethTxHash,
│       celestiaProof
│   )
├─ Bridge verifica:
│   ├─ !processedTransactions[ethTxHash] ✓
│   ├─ _verifyBlobstreamProof() ✓
│   ├─ supportedTokens[ABOB] ✓
│   └─ Rate limits ✓
├─ processedTransactions[ethTxHash] = true
├─ ABOB.mint(recipientAddress, 1000) ✓
└─ emit TokensReceived(...)

RESULTADO:
Usuario en Bolivia recibe 1000 ABOB en AndeChain
Tiempo total: ~5-10 minutos
Costo: ~$2 (gas Ethereum) + $0.01 (gas AndeChain)
```

---

### Escape Hatch: Forced Transaction

```
ESCENARIO: Relayer está offline o censurando

USUARIO ACCIÓN:
├─ Usuario espera forceInclusionPeriod (ej: 6 horas)
├─ Usuario obtiene Merkle proof de Celestia directamente
└─ Usuario llama: bridge.forceTransaction(txData, proof)

CONTRACT LOGIC:
├─ Verifica: !processedTransactions[txData.sourceTxHash] ✓
├─ Verifica: _verifyBlobstreamProof() ✓
├─ Verifica: block.timestamp >= txData.blockTimestamp + forceInclusionPeriod ✓
├─ processedTransactions[txData.sourceTxHash] = true
├─ IXERC20(txData.token).mint(txData.recipient, txData.amount) ✓
└─ emit TokensReceived(...)

RESULTADO:
Usuario puede auto-servirse el bridging sin depender del relayer
Garantía de sovereignty: fondos SIEMPRE recuperables
```

---

## Consideraciones de Seguridad

### Vectores de Ataque y Mitigaciones

#### 1. Oracle Manipulation

**Ataque:** Manipular precio ANDE para mint ABOB con menos colateral

**Mitigaciones Implementadas:**
- ✅ P2POracleV2 usa mediana ponderada por stake (resistente a outliers)
- ✅ Reporters deben stake ANDE (alineación de incentivos)
- ✅ Slashing por reportar precios fuera de rango

**Mitigaciones Futuras:**
- [ ] Circuit breakers: pausar mint si precio diverge >5% en 1 hora
- [ ] Multiple oracle sources (Chainlink + Pyth + P2P)
- [ ] TWAP (Time-Weighted Average Price) sobre varias horas
- [ ] Community monitoring dashboard con alertas

---

#### 2. Flash Loan Attacks

**Ataque:**
1. Flash loan 10M ANDE
2. Manipular precio en DEX
3. Mint ABOB con ANDE "barato"
4. Repay flash loan
5. Profit

**Mitigaciones Implementadas:**
- ✅ Oracle usa precio histórico (epoch-based), no spot price
- ✅ nonReentrant en mint/redeem
- ✅ Pausable en caso de detección

**Mitigaciones Futuras:**
- [ ] Minimum mint/redeem amounts (evitar micro-arbitrage)
- [ ] Cooldown periods entre mint/redeem del mismo usuario
- [ ] Monitor for unusual mint/redeem patterns
- [ ] Insurance fund para cubrir pérdidas

---

#### 3. Bridge Replay Attacks

**Ataque:** Re-usar proof de bridging para mint múltiples veces

**Mitigaciones Implementadas:**
- ✅ `processedTransactions[txHash]` mapping
- ✅ Verifica transaction no procesada antes de mint
- ✅ Unique nonce por cada bridging

---

#### 4. Reentrancy

**Ataque:** Re-entrar en mint() durante external call

**Mitigaciones Implementadas:**
- ✅ `nonReentrant` modifier en todas las funciones con external calls
- ✅ Checks-Effects-Interactions pattern (burn before transfers)
- ✅ Use of SafeERC20 para calls a tokens externos

---

#### 5. Collateral Liquidation Cascade

**Escenario:** ANDE precio cae 50% en 1 día

**Impacto:**
```
Antes:
ABOB Supply: 1M tokens
AUSD Collateral: 700k AUSD
ANDE Collateral: 1M ANDE @ $0.30 = $300k
Total Collateral: $1M
Health Ratio: 100%

Después (ANDE -50%):
AUSD Collateral: 700k AUSD
ANDE Collateral: 1M ANDE @ $0.15 = $150k
Total Collateral: $850k
Health Ratio: 85% (undercollateralized!)
```

**Respuestas Automáticas:**
1. Emergency pause de nuevos mints
2. Ajuste automático de collateralRatio (aumentar AUSD component)
3. Incentivos para burn ABOB (small premium)
4. Insurance fund injection

**Código Propuesto:**
```solidity
function checkAndRebalance() external {
    uint256 healthRatio = getSystemHealthRatio();

    if (healthRatio < 9500) { // <95% collateralized
        // Aumentar ratio AUSD component
        uint256 newRatio = collateralRatio + 500; // +5%
        if (newRatio > 9500) newRatio = 9500; // Max 95% AUSD

        collateralRatio = newRatio;

        emit EmergencyRebalance(healthRatio, newRatio);
    }

    if (healthRatio < 8500) { // <85% collateralized
        _pause(); // Stop new mints
        emit EmergencyPause(healthRatio);
    }
}
```

---

## Ejemplos de Código

### Integración con Frontend

```typescript
// ande-frontend/src/lib/abob.ts

import { ethers } from 'ethers';
import AbobTokenABI from './abis/AbobToken.json';

export class AbobService {
  private abobContract: ethers.Contract;

  constructor(provider: ethers.Provider, contractAddress: string) {
    this.abobContract = new ethers.Contract(
      contractAddress,
      AbobTokenABI,
      provider
    );
  }

  // Mint ABOB
  async mintAbob(
    signer: ethers.Signer,
    amountAbob: string
  ): Promise<ethers.TransactionResponse> {
    const contract = this.abobContract.connect(signer);

    // Calcular colateral requerido
    const { ausdNeeded, andeNeeded } = await this.calculateCollateralNeeded(
      ethers.parseEther(amountAbob)
    );

    // Aprobar AUSD
    const ausdToken = new ethers.Contract(
      await contract.ausdToken(),
      ['function approve(address,uint256)'],
      signer
    );
    await ausdToken.approve(contract.target, ausdNeeded);

    // Aprobar ANDE
    const andeToken = new ethers.Contract(
      await contract.andeToken(),
      ['function approve(address,uint256)'],
      signer
    );
    await andeToken.approve(contract.target, andeNeeded);

    // Mint ABOB
    return await contract.mint(ethers.parseEther(amountAbob));
  }

  // Calcular colateral necesario
  async calculateCollateralNeeded(
    amountAbob: bigint
  ): Promise<{ ausdNeeded: bigint; andeNeeded: bigint }> {
    const [
      collateralRatio,
      andePriceFeed,
      abobPriceFeed
    ] = await Promise.all([
      this.abobContract.collateralRatio(),
      this.abobContract.andePriceFeed(),
      this.abobContract.abobPriceFeed()
    ]);

    // Get prices from oracles
    const andePriceFeedContract = new ethers.Contract(
      andePriceFeed,
      ['function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)'],
      this.abobContract.runner
    );
    const abobPriceFeedContract = new ethers.Contract(
      abobPriceFeed,
      ['function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)'],
      this.abobContract.runner
    );

    const [, andePriceRaw] = await andePriceFeedContract.latestRoundData();
    const [, abobPriceRaw] = await abobPriceFeedContract.latestRoundData();

    const andePrice = BigInt(andePriceRaw);
    const abobPrice = BigInt(abobPriceRaw);

    // Calculate
    const totalCollateralValueInUSD = (amountAbob * abobPrice) / ethers.parseEther('1');
    const ausdNeeded = (totalCollateralValueInUSD * collateralRatio) / 10000n;
    const andeValueInUSD = totalCollateralValueInUSD - ausdNeeded;
    const andeNeeded = (andeValueInUSD * ethers.parseEther('1')) / andePrice;

    return { ausdNeeded, andeNeeded };
  }

  // Get user balance
  async getBalance(address: string): Promise<string> {
    const balance = await this.abobContract.balanceOf(address);
    return ethers.formatEther(balance);
  }

  // Redeem ABOB
  async redeemAbob(
    signer: ethers.Signer,
    amountAbob: string
  ): Promise<ethers.TransactionResponse> {
    const contract = this.abobContract.connect(signer);
    return await contract.redeem(ethers.parseEther(amountAbob));
  }
}
```

---

### Backend Monitor Script

```typescript
// scripts/monitor-abob-health.ts

import { ethers } from 'ethers';
import { AbobService } from './abob-service';

async function monitorSystemHealth() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const abobService = new AbobService(provider, process.env.ABOB_ADDRESS!);

  // Get system stats
  const totalSupply = await abobService.contract.totalSupply();
  const ausdBalance = await abobService.getAusdBalance();
  const andeBalance = await abobService.getAndeBalance();
  const andePrice = await abobService.getAndePrice();

  // Calculate health ratio
  const ausdValue = ausdBalance;
  const andeValue = (andeBalance * andePrice) / ethers.parseEther('1');
  const totalCollateral = ausdValue + andeValue;

  const healthRatio = totalSupply > 0n
    ? (totalCollateral * 10000n) / totalSupply
    : 0n;

  console.log('=== ABOB System Health ===');
  console.log(`Total ABOB Supply: ${ethers.formatEther(totalSupply)}`);
  console.log(`AUSD Collateral: $${ethers.formatEther(ausdValue)}`);
  console.log(`ANDE Collateral: $${ethers.formatEther(andeValue)}`);
  console.log(`Health Ratio: ${Number(healthRatio) / 100}%`);

  // Alert if unhealthy
  if (healthRatio < 9500n) {
    await sendAlert(`⚠️ ABOB undercollateralized: ${Number(healthRatio) / 100}%`);
  }

  if (healthRatio < 8500n) {
    await sendCriticalAlert(`🚨 CRITICAL: ABOB health ${Number(healthRatio) / 100}%`);
  }
}

// Run every 5 minutes
setInterval(monitorSystemHealth, 5 * 60 * 1000);
```

---

## Conclusión

El sistema ABOB representa una arquitectura sofisticada de stablecoin híbrida que combina:

✅ **Estabilidad** (colateral dual AUSD+ANDE)
✅ **Yield** (sABOB vault con protocol revenue)
✅ **Cross-chain** (xERC20 bridge con escape hatches)
✅ **Descentralización** (P2P oracles, gobernanza on-chain)
✅ **Seguridad** (auditorías, rate limits, circuit breakers)

**Siguiente Milestone:** Completar xERC20 bridge y deployment en testnet público.

---

**Autor:** Ande Labs Technical Team
**Última Actualización:** 6 de Octubre, 2025
**Versión:** 1.0
