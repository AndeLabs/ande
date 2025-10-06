// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// Core Tokens
import {ANDEToken} from "../src/ANDEToken.sol";
import {AusdToken} from "../src/AusdToken.sol";
import {AbobToken} from "../src/AbobToken.sol";
import {sAbobToken} from "../src/sAbobToken.sol";

// Governance & Tokenomics
import {VeANDE} from "../src/VeANDE.sol";
import {MintController} from "../src/MintController.sol";
import {DualTrackBurnEngine} from "../src/DualTrackBurnEngine.sol";

// Stability & Oracles
import {StabilityEngine} from "../src/StabilityEngine.sol";
import {P2POracleV2} from "../src/P2POracleV2.sol";
import {TrustedRelayerOracle} from "../src/TrustedRelayerOracle.sol";
import {AndeOracleAggregator} from "../src/AndeOracleAggregator.sol";

// Bridge
import {AndeBridge} from "../src/AndeBridge.sol";
import {EthereumBridge} from "../src/EthereumBridge.sol";

// Mocks (para desarrollo local)
import {MockERC20} from "../src/mocks/MockERC20.sol";
import {MockOracle} from "../src/mocks/MockOracle.sol";

/**
 * @title DeployEcosystem
 * @notice Script completo para desplegar todo el ecosistema AndeChain
 * @dev Despliega tokens, governance, oracles, stability engine y bridge
 *
 * Uso:
 * forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url local --broadcast --verify --legacy
 */
contract DeployEcosystem is Script {
    // Configuración
    uint256 constant INITIAL_COLLATERAL_RATIO = 150; // 150% para StabilityEngine
    uint256 constant ORACLE_STAKE = 1000 * 1e18; // Stake mínimo para P2P Oracle
    uint256 constant EPOCH_DURATION = 3600; // 1 hora
    uint256 constant ANDE_PRICE_USD = 2 * 10**8; // $2 USD con 8 decimales
    uint256 constant USDC_PRICE_USD = 1 * 10**8; // $1 USD
    uint256 constant MINT_HARD_CAP = 1_000_000_000 * 1e18; // 1 billón de tokens
    uint256 constant ANNUAL_MINT_LIMIT = 50_000_000 * 1e18; // 50 millones de tokens

    // Direcciones desplegadas (se actualizan durante el despliegue)
    struct DeployedContracts {
        // Core Tokens
        address andeToken;
        address ausdToken;
        address abobToken;
        address sAbobToken;
        // Governance
        address veANDE;
        address mintController;
        address burnEngine;
        // Oracles
        address p2pOracle;
        address trustedOracle;
        address oracleAggregator;
        address andeUsdOracle; // Mock
        address usdcOracle; // Mock
        address abobUsdOracle; // Mock for ABOB
        // Stability
        address stabilityEngine;
        // Bridge
        address andeBridge;
        address ethereumBridge;
        // Mocks
        address mockUsdc;
        address mockBlobstream;
    }

    DeployedContracts public deployed;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("===========================================");
        console.log("  ANDECHAIN ECOSYSTEM DEPLOYMENT");
        console.log("===========================================");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Mocks & Oracles
        _deployMocks();

        // 2. Deploy Core Tokens
        _deployCoreTokens(deployer);

        // 3. Deploy Governance
        _deployGovernance(deployer);

        // 4. Deploy Oracles
        _deployOracles(deployer);

        // 5. Deploy Stability Engine
        _deployStability(deployer);

        // 6. Deploy Bridge
        _deployBridge();

        // 7. Setup Roles & Permissions
        _setupRoles();

        vm.stopBroadcast();

        // 8. Print Summary
        _printSummary();
    }

    function _deployMocks() internal {
        console.log("--- Step 1: Deploying Mocks ---");

        // Mock USDC para testing
        MockERC20 mockUsdc = new MockERC20("Mock USDC", "mUSDC", 6);
        deployed.mockUsdc = address(mockUsdc);
        console.log("MockUSDC:", deployed.mockUsdc);

        // Mock Oracles
        MockOracle andeUsdOracle = new MockOracle();
        andeUsdOracle.setPrice(ANDE_PRICE_USD);
        deployed.andeUsdOracle = address(andeUsdOracle);
        console.log("ANDE/USD Oracle (Mock):", deployed.andeUsdOracle);

        MockOracle usdcOracle = new MockOracle();
        usdcOracle.setPrice(USDC_PRICE_USD);
        deployed.usdcOracle = address(usdcOracle);
        console.log("USDC/USD Oracle (Mock):", deployed.usdcOracle);

        // Mock Blobstream para bridge
        deployed.mockBlobstream = address(new MockBlobstream());
        console.log("MockBlobstream:", deployed.mockBlobstream);

        // Mock Oracle para ABOB/USD (ej: 1 BOB = 0.14 USD)
        MockOracle abobUsdOracle = new MockOracle();
        abobUsdOracle.setPrice(14 * 10**6); // 0.14 USD con 8 decimales
        deployed.abobUsdOracle = address(abobUsdOracle);
        console.log("ABOB/USD Oracle (Mock):", deployed.abobUsdOracle);

        console.log("");
    }

    function _deployCoreTokens(address owner) internal {
        console.log("--- Step 2: Deploying Core Tokens ---");

        // ANDE Token (Governance Token)
        ANDEToken andeImpl = new ANDEToken();
        bytes memory andeInit = abi.encodeWithSelector(
            ANDEToken.initialize.selector,
            owner,
            owner
        );
        deployed.andeToken = address(new ERC1967Proxy(address(andeImpl), andeInit));
        console.log("ANDEToken (Proxy):", deployed.andeToken);

        // aUSD Token (Stablecoin)
        AusdToken ausdImpl = new AusdToken();
        bytes memory ausdInit = abi.encodeWithSelector(AusdToken.initialize.selector, owner);
        deployed.ausdToken = address(new ERC1967Proxy(address(ausdImpl), ausdInit));
        console.log("AusdToken (Proxy):", deployed.ausdToken);

        // ABOB Token (Boliviano-pegged)
        AbobToken abobImpl = new AbobToken();
        bytes memory abobInit = abi.encodeWithSelector(
            AbobToken.initialize.selector,
            owner, // defaultAdmin
            owner, // pauser
            owner, // governance
            deployed.ausdToken,
            deployed.andeToken,
            deployed.andeUsdOracle,
            deployed.abobUsdOracle,
            8000 // 80% initial collateral ratio
        );
        deployed.abobToken = address(new ERC1967Proxy(address(abobImpl), abobInit));
        console.log("AbobToken (Proxy):", deployed.abobToken);

        // sABOB Token (Staked ABOB)
        sAbobToken sAbobImpl = new sAbobToken();
        bytes memory sAbobInit = abi.encodeWithSelector(
            sAbobToken.initialize.selector,
            owner,
            deployed.abobToken
        );
        deployed.sAbobToken = address(new ERC1967Proxy(address(sAbobImpl), sAbobInit));
        console.log("sAbobToken (Proxy):", deployed.sAbobToken);
        console.log("");
    }

    function _deployGovernance(address owner) internal {
        console.log("--- Step 3: Deploying Governance ---");

        // VeANDE (Vote-escrowed ANDE)
        VeANDE veAndeImpl = new VeANDE();
        bytes memory veInit = abi.encodeWithSelector(
            VeANDE.initialize.selector,
            owner,
            deployed.andeToken
        );
        deployed.veANDE = address(new ERC1967Proxy(address(veAndeImpl), veInit));
        console.log("VeANDE (Proxy):", deployed.veANDE);

        // MintController
        MintController mintImpl = new MintController();
        bytes memory mintInit = abi.encodeWithSelector(
            MintController.initialize.selector,
            owner, // defaultAdmin
            owner, // governance
            owner, // guardian
            deployed.andeToken,
            deployed.veANDE,
            MINT_HARD_CAP,
            ANNUAL_MINT_LIMIT
        );
        deployed.mintController = address(new ERC1967Proxy(address(mintImpl), mintInit));
        console.log("MintController (Proxy):", deployed.mintController);

        // DualTrackBurnEngine
        DualTrackBurnEngine burnImpl = new DualTrackBurnEngine();
        bytes memory burnInit = abi.encodeWithSelector(
            DualTrackBurnEngine.initialize.selector,
            owner, // defaultAdmin
            owner, // burner
            deployed.andeToken
        );
        deployed.burnEngine = address(new ERC1967Proxy(address(burnImpl), burnInit));
        console.log("DualTrackBurnEngine (Proxy):", deployed.burnEngine);
        console.log("");
    }

    function _deployOracles(address owner) internal {
        console.log("--- Step 4: Deploying Oracles ---");

        // P2P Oracle V2
        P2POracleV2 p2pImpl = new P2POracleV2();
        bytes memory p2pInit = abi.encodeWithSelector(
            P2POracleV2.initialize.selector,
            owner,
            deployed.andeToken,
            ORACLE_STAKE,
            EPOCH_DURATION
        );
        deployed.p2pOracle = address(new ERC1967Proxy(address(p2pImpl), p2pInit));
        console.log("P2POracleV2 (Proxy):", deployed.p2pOracle);

        // Trusted Relayer Oracle
        TrustedRelayerOracle trustedImpl = new TrustedRelayerOracle();
        bytes memory trustedInit = abi.encodeWithSelector(
            TrustedRelayerOracle.initialize.selector,
            owner
        );
        deployed.trustedOracle = address(new ERC1967Proxy(address(trustedImpl), trustedInit));
        console.log("TrustedRelayerOracle (Proxy):", deployed.trustedOracle);

        // Oracle Aggregator
        address[] memory oracles = new address[](2);
        oracles[0] = deployed.p2pOracle;
        oracles[1] = deployed.trustedOracle;

        AndeOracleAggregator aggImpl = new AndeOracleAggregator();
        bytes memory aggInit = abi.encodeWithSelector(
            AndeOracleAggregator.initialize.selector,
            owner,
            oracles
        );
        deployed.oracleAggregator = address(new ERC1967Proxy(address(aggImpl), aggInit));
        console.log("AndeOracleAggregator (Proxy):", deployed.oracleAggregator);
        console.log("");
    }

    function _deployStability(address owner) internal {
        console.log("--- Step 5: Deploying Stability Engine ---");

        StabilityEngine engineImpl = new StabilityEngine();
        bytes memory engineInit = abi.encodeWithSelector(
            StabilityEngine.initialize.selector,
            owner,
            deployed.andeToken,
            deployed.ausdToken,
            deployed.andeUsdOracle,
            INITIAL_COLLATERAL_RATIO
        );
        deployed.stabilityEngine = address(new ERC1967Proxy(address(engineImpl), engineInit));
        console.log("StabilityEngine (Proxy):", deployed.stabilityEngine);
        console.log("");
    }

    function _deployBridge() internal {
        console.log("--- Step 6: Deploying Bridge ---");

        AndeBridge andeBridge = new AndeBridge(deployed.abobToken);
        deployed.andeBridge = address(andeBridge);
        console.log("AndeBridge:", deployed.andeBridge);

        EthereumBridge ethBridge = new EthereumBridge(
            deployed.mockBlobstream,
            deployed.mockUsdc
        );
        deployed.ethereumBridge = address(ethBridge);
        console.log("EthereumBridge:", deployed.ethereumBridge);
        console.log("");
    }

    function _setupRoles() internal {
        console.log("--- Step 7: Setting up Roles & Permissions ---");

        // Grant MINTER_ROLE to StabilityEngine for aUSD
        AusdToken(deployed.ausdToken).grantRole(
            AusdToken(deployed.ausdToken).MINTER_ROLE(),
            deployed.stabilityEngine
        );
        console.log("Granted MINTER_ROLE to StabilityEngine");

        // Grant BURNER_ROLE to StabilityEngine for aUSD
        AusdToken(deployed.ausdToken).grantRole(
            AusdToken(deployed.ausdToken).BURNER_ROLE(),
            deployed.stabilityEngine
        );
        console.log("Granted BURNER_ROLE to StabilityEngine");

        // Grant MINTER_ROLE to MintController for ANDE
        ANDEToken(deployed.andeToken).grantRole(
            ANDEToken(deployed.andeToken).MINTER_ROLE(),
            deployed.mintController
        );
        console.log("Granted MINTER_ROLE to MintController");

        // Grant BURNER_ROLE to DualTrackBurnEngine for ANDE
        ANDEToken(deployed.andeToken).grantRole(
            ANDEToken(deployed.andeToken).BURNER_ROLE(),
            deployed.burnEngine
        );
        console.log("Granted BURNER_ROLE to DualTrackBurnEngine");

        // Add USDC as collateral type for aUSD
        AusdToken(deployed.ausdToken).addCollateralType(
            deployed.mockUsdc,
            12000, // 120% collateralization
            deployed.usdcOracle
        );
        console.log("Added USDC as collateral type for aUSD");
        console.log("");
    }

    function _printSummary() internal view {
        console.log("===========================================");
        console.log("  DEPLOYMENT SUMMARY");
        console.log("===========================================");
        console.log("");
        console.log("CORE TOKENS:");
        console.log("  ANDE Token:        ", deployed.andeToken);
        console.log("  aUSD Token:        ", deployed.ausdToken);
        console.log("  ABOB Token:        ", deployed.abobToken);
        console.log("  sABOB Token:       ", deployed.sAbobToken);
        console.log("");
        console.log("GOVERNANCE:");
        console.log("  VeANDE:            ", deployed.veANDE);
        console.log("  MintController:    ", deployed.mintController);
        console.log("  BurnEngine:        ", deployed.burnEngine);
        console.log("");
        console.log("ORACLES:");
        console.log("  P2P Oracle:        ", deployed.p2pOracle);
        console.log("  Trusted Oracle:    ", deployed.trustedOracle);
        console.log("  Oracle Aggregator: ", deployed.oracleAggregator);
        console.log("  ANDE/USD Oracle:   ", deployed.andeUsdOracle);
        console.log("  USDC/USD Oracle:   ", deployed.usdcOracle);
        console.log("");
        console.log("STABILITY:");
        console.log("  StabilityEngine:   ", deployed.stabilityEngine);
        console.log("");
        console.log("BRIDGE:");
        console.log("  AndeBridge:        ", deployed.andeBridge);
        console.log("  EthereumBridge:    ", deployed.ethereumBridge);
        console.log("");
        console.log("MOCKS:");
        console.log("  MockUSDC:          ", deployed.mockUsdc);
        console.log("  MockBlobstream:    ", deployed.mockBlobstream);
        console.log("===========================================");
        console.log("");
        console.log("Next steps:");
        console.log("1. Verify contracts: forge verify-contract --chain-id 1234 ...");
        console.log("2. Update frontend with deployed addresses");
        console.log("3. Test interactions via Blockscout: http://localhost:4000");
    }
}

// Mock Blobstream contract
contract MockBlobstream {
    mapping(uint256 => bytes32) public dataRoots;

    function setDataRoot(uint256 _blockNumber, bytes32 _root) public {
        dataRoots[_blockNumber] = _root;
    }

    function dataRootTupleRootAtBlock(uint256 _blockNumber) external view returns (bytes32) {
        return dataRoots[_blockNumber];
    }
}
