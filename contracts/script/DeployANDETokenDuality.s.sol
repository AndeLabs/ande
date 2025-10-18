// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ANDETokenDuality} from "../src/ANDETokenDuality.sol";
import {NativeTransferPrecompileMock} from "../src/mocks/NativeTransferPrecompileMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/**
 * @title DeployANDETokenDuality
 * @notice Script de deployment production-ready para ANDETokenDuality
 * @dev Este script:
 *      - Deploy del precompile mock (solo local/testnet)
 *      - Deploy de ANDETokenDuality implementation
 *      - Deploy de ERC1967Proxy
 *      - Inicialización del sistema
 *      - Mint inicial al deployer y faucet
 */
contract DeployANDETokenDuality is Script {
    // ==========================================
    // CONSTANTS - PRODUCTION
    // ==========================================
    
    /// @notice Dirección del precompile nativo en producción
    address public constant PRODUCTION_PRECOMPILE = 0x00000000000000000000000000000000000000fd;
    
    /// @notice Hardhat Account #0 - Deployer & Admin
    address public constant DEPLOYER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    uint256 public constant DEPLOYER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    
    /// @notice Initial supply para producción: 100M ANDE para faucet
    uint256 public constant INITIAL_FAUCET_SUPPLY = 100_000_000 * 10**18;
    
    /// @notice Supply adicional para deployer (testing)
    uint256 public constant DEPLOYER_SUPPLY = 1_000_000 * 10**18;

    // ==========================================
    // STATE VARIABLES
    // ==========================================
    
    address payable public precompileAddress;
    address public implementationAddress;
    address public proxyAddress;
    ANDETokenDuality public andeToken;

    // ==========================================
    // MAIN DEPLOYMENT FUNCTION
    // ==========================================

    function run() external {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        console.log("===========================================");
        console.log("ANDE Token Duality - Production Deployment");
        console.log("===========================================");
        console.log("Deployer:", DEPLOYER);
        console.log("");

        // PASO 1: Deploy Precompile (Mock para local/testnet)
        precompileAddress = deployPrecompile();
        
        // PASO 2: Deploy Implementation
        implementationAddress = deployImplementation();
        
        // PASO 3: Deploy Proxy
        proxyAddress = deployProxy();
        
        // PASO 4: Inicializar
        initializeToken();
        
        // PASO 5: Mint initial supply
        mintInitialSupply();
        
        // PASO 6: Verificaciones
        verifyDeployment();

        console.log("");
        console.log("===========================================");
        console.log("Deployment Complete!");
        console.log("===========================================");
        console.log("Precompile Address:      ", precompileAddress);
        console.log("Implementation Address:  ", implementationAddress);
        console.log("Proxy Address (USE THIS):", proxyAddress);
        console.log("===========================================");
        console.log("");
        console.log("Update your frontend:");
        console.log("ANDE_TOKEN_ADDRESS =", proxyAddress);
        console.log("");

        vm.stopBroadcast();
    }

    // ==========================================
    // DEPLOYMENT STEPS
    // ==========================================

    /**
     * @notice Deploy del precompile mock
     * @dev En producción real, esta dirección sería 0x...FD (hardcoded en Reth)
     * @return Dirección del precompile deployado
     */
    function deployPrecompile() internal returns (address payable) {
        console.log("Step 1: Deploying Precompile Mock...");
        
        // Check si ya existe el precompile de producción
        if (PRODUCTION_PRECOMPILE.code.length > 0) {
            console.log("  Production precompile detected at:", PRODUCTION_PRECOMPILE);
            console.log("  Using production precompile");
            return payable(PRODUCTION_PRECOMPILE);
        }
        
        // Deploy mock para local/testnet
        // IMPORTANTE: El proxy address aún no existe, entonces pasamos address(0)
        // y luego actualizaremos con setAuthorizedCaller()
        NativeTransferPrecompileMock precompileMock = new NativeTransferPrecompileMock(address(0));
        
        console.log("  Mock precompile deployed to:", address(precompileMock));
        console.log("  (Will be updated with token address after proxy deployment)");
        
        return payable(address(precompileMock));
    }

    /**
     * @notice Deploy de ANDETokenDuality implementation
     * @return Dirección de la implementation
     */
    function deployImplementation() internal returns (address) {
        console.log("");
        console.log("Step 2: Deploying ANDETokenDuality Implementation...");
        
        ANDETokenDuality implementation = new ANDETokenDuality();
        
        console.log("  Implementation deployed to:", address(implementation));
        
        return address(implementation);
    }

    /**
     * @notice Deploy del ERC1967 Proxy
     * @return Dirección del proxy
     */
    function deployProxy() internal returns (address) {
        console.log("");
        console.log("Step 3: Deploying ERC1967 Proxy...");
        
        // Preparar datos de inicialización
        bytes memory initData = abi.encodeWithSignature(
            "initialize(address,address,address)",
            DEPLOYER,          // defaultAdmin
            DEPLOYER,          // minter (será el que mintee tokens)
            precompileAddress  // precompile address
        );
        
        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(
            implementationAddress,
            initData
        );
        
        console.log("  Proxy deployed to:", address(proxy));
        
        return address(proxy);
    }

    /**
     * @notice Inicializa el token y configura el precompile
     */
    function initializeToken() internal {
        console.log("");
        console.log("Step 4: Initializing Token...");
        
        // Conectar al proxy como ANDETokenDuality
        andeToken = ANDETokenDuality(proxyAddress);
        
        // Verificar inicialización
        console.log("  Token Name:", andeToken.name());
        console.log("  Token Symbol:", andeToken.symbol());
        console.log("  Decimals:", andeToken.decimals());
        console.log("  Precompile:", andeToken.precompileAddress());
        console.log("  Admin:", DEPLOYER);
        
        // Si estamos usando el mock, actualizar el authorized caller
        if (precompileAddress != PRODUCTION_PRECOMPILE) {
            console.log("");
            console.log("  Updating mock precompile authorized caller...");
            NativeTransferPrecompileMock(precompileAddress).setAuthorizedCaller(proxyAddress);
            console.log("  Mock updated with token address");
        }
    }

    /**
     * @notice Mintea supply inicial al faucet y deployer
     */
    function mintInitialSupply() internal {
        console.log("");
        console.log("Step 5: Minting Initial Supply...");
        
        // Mint para faucet (100M ANDE)
        console.log("  Minting to Faucet:", DEPLOYER);
        console.log("  Amount:", INITIAL_FAUCET_SUPPLY / 10**18, "ANDE");
        andeToken.mint(DEPLOYER, INITIAL_FAUCET_SUPPLY);
        
        console.log("");
        console.log("  Initial supply minted successfully");
        console.log("  Faucet balance:", andeToken.balanceOf(DEPLOYER) / 10**18, "ANDE");
    }

    /**
     * @notice Verifica que el deployment fue exitoso
     */
    function verifyDeployment() internal view {
        console.log("");
        console.log("Step 6: Verifying Deployment...");
        
        // Verificar balances
        uint256 faucetBalance = andeToken.balanceOf(DEPLOYER);
        require(faucetBalance >= INITIAL_FAUCET_SUPPLY, "Faucet balance incorrect");
        console.log("  Faucet Balance: OK");
        
        // Verificar total supply
        uint256 supply = andeToken.totalSupply();
        console.log("  Total Supply:", supply / 10**18, "ANDE");
        
        // Verificar roles
        bytes32 adminRole = andeToken.DEFAULT_ADMIN_ROLE();
        bytes32 minterRole = andeToken.MINTER_ROLE();
        
        require(andeToken.hasRole(adminRole, DEPLOYER), "Admin role not set");
        console.log("  Admin Role: OK");
        
        require(andeToken.hasRole(minterRole, DEPLOYER), "Minter role not set");
        console.log("  Minter Role: OK");
        
        // Verificar precompile
        require(andeToken.precompileAddress() == precompileAddress, "Precompile not set");
        console.log("  Precompile: OK");
        
        console.log("");
        console.log("  All verifications passed!");
    }

    // ==========================================
    // HELPER FUNCTIONS
    // ==========================================

    /**
     * @notice Retorna las direcciones deployadas para otros scripts
     */
    function getDeployedAddresses() external view returns (
        address _precompile,
        address _implementation,
        address _proxy,
        address _token
    ) {
        return (
            precompileAddress,
            implementationAddress,
            proxyAddress,
            proxyAddress  // token es el proxy
        );
    }
}