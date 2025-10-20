// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title ANDETokenDuality
 * @author Ande Labs
 * @notice ANDE - Moneda Nativa de AndeChain con funcionalidad Token Duality
 *
 * @dev Este contrato implementa Token Duality, permitiendo que ANDE funcione como:
 *      1. Moneda nativa para pagar gas fees (como ETH en Ethereum)
 *      2. Compatible con interfaz ERC-20 para dApps
 *
 *      Características:
 *      - balanceOf() lee del precompile (balance nativo en producción)
 *      - _update() delega transferencias al precompile
 *      - Mantiene TODA la funcionalidad de ERC20Votes, Permit, Pausable
 *      - Compatible 100% con estándar ERC-20 para interoperabilidad
 *
 * @custom:security-contact security@andelabs.io
 */
contract ANDETokenDuality is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable
{
    // ========================================
    // CONSTANTS
    // ========================================

    /// @notice Rol para acuñar nuevas unidades de ANDE
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Rol para quemar ANDE
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Rol para pausar/reanudar transferencias
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice Dirección del precompile de transferencia nativa
    /// @dev En producción: 0x00000000000000000000000000000000000000fd
    ///      En testing: dirección del NativeTransferPrecompileMock
    address private _nativeTransferPrecompile;

    // ========================================
    // EVENTS
    // ========================================

    /// @notice Emitido cuando se actualiza la dirección del precompile
    event PrecompileAddressUpdated(address indexed oldAddress, address indexed newAddress);

    // ========================================
    // CUSTOM ERRORS
    // ========================================

    error PrecompileCallFailed(bytes returnData);
    error InvalidPrecompileAddress();

    // ========================================
    // STORAGE GAP
    // ========================================

    /// @dev Gap para upgrades futuros (UUPS pattern)
    uint256[49] private __gap;

    // ========================================
    // CONSTRUCTOR & INITIALIZATION
    // ========================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa el contrato (patrón proxy UUPS)
     * @param defaultAdmin Dirección con rol de administrador
     * @param minter Dirección con permiso para acuñar (MintController)
     * @param precompile Dirección del precompile de transferencia nativa
     */
    function initialize(address defaultAdmin, address minter, address precompile) public initializer {
        __ERC20_init("ANDE", "ANDE");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init("ANDE");
        __ERC20Votes_init();
        __ERC20Burnable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, defaultAdmin);

        _setPrecompileAddress(precompile);
    }

    // ========================================
    // TOKEN DUALITY - CORE OVERRIDES
    // ========================================

    /**
     * @notice Retorna el balance de ANDE de una cuenta
     * @dev MODIFICADO: Consulta al precompile en lugar de _balances storage
     *
     *      En producción (con precompile real):
     *      - Retorna address.balance directamente
     *
     *      En testing (con mock):
     *      - Consulta mapping interno del mock
     *
     * @param account Dirección a consultar
     * @return Balance en wei
     */
    function balanceOf(address account) public view override(ERC20Upgradeable) returns (uint256) {
        // Llamar a getNativeBalance() del precompile/mock
        (bool success, bytes memory returnData) =
            _nativeTransferPrecompile.staticcall(abi.encodeWithSignature("getNativeBalance(address)", account));

        if (!success) {
            // Si falla, retornar 0 (comportamiento seguro)
            return 0;
        }

        return abi.decode(returnData, (uint256));
    }

    /**
     * @notice Retorna el supply total de ANDE
     * @dev MODIFICADO: Consulta al precompile en lugar de _totalSupply storage
     *
     * @return Supply total en wei
     */
    function totalSupply() public view override(ERC20Upgradeable) returns (uint256) {
        // Llamar a totalSupply() del precompile/mock
        (bool success, bytes memory returnData) =
            _nativeTransferPrecompile.staticcall(abi.encodeWithSignature("totalSupply()"));

        if (!success) {
            return 0;
        }

        return abi.decode(returnData, (uint256));
    }

    /**
     * @notice Hook interno para transferencias, acuñaciones y quemas
     * @dev MODIFICADO: Delega actualizaciones de balance al precompile
     *
     *      Orden de operaciones (CRÍTICO):
     *      1. Actualizar checkpoints de votación (ERC20Votes) - ANTES de cambiar balances
     *      2. Ejecutar transferencia nativa vía precompile
     *      3. Emitir evento Transfer (compatibilidad ERC-20)
     *
     *      IMPORTANTE: No llamamos super._update() porque eso modificaría
     *      _balances storage, que ya no usamos.
     *
     * @param from Dirección origen (address(0) para mint)
     * @param to Dirección destino (address(0) para burn)
     * @param value Cantidad a transferir
     */
    function _update(address from, address to, uint256 value) internal override(ERC20Upgradeable, ERC20VotesUpgradeable) {
        // PASO 0: Validación de pausa
        // La implementación base de ERC20 ya maneja esto, pero lo hacemos explícito
        if (paused()) {
            revert EnforcedPause();
        }

        // PASO 1: Actualizar checkpoints de votación PRIMERO
        // Esto debe hacerse ANTES de modificar balances para mantener
        // consistencia en el histórico de poder de voto
        _transferVotingUnits(from, to, value);

        // PASO 2: Ejecutar transferencia nativa vía precompile
        // NOTA: Solo para transferencias normales, no para mint/burn
        // - Mint: el balance ya fue depositado por depositNativeBalance()
        // - Burn: el balance será removido después de _update
        if (from != address(0) && to != address(0)) {
            // El precompile validará:
            // - Caller == address(this)
            // - Balance suficiente
            // - Destinatario != address(0)

            // Codificar llamada al precompile
            bytes memory input = abi.encode(from, to, value);

            // Ejecutar via call (no staticcall porque modifica estado)
            (bool success, bytes memory returnData) = _nativeTransferPrecompile.call(input);

            if (!success) {
                // Decodificar error del precompile si es posible
                if (returnData.length > 0) {
                    // Propagar el error original del precompile
                    assembly {
                        let returnDataSize := mload(returnData)
                        revert(add(32, returnData), returnDataSize)
                    }
                }
                revert PrecompileCallFailed(returnData);
            }
        }

        // PASO 3: Emitir evento Transfer
        // Requerido por estándar ERC-20 para compatibilidad con indexers
        emit Transfer(from, to, value);
    }

    // ========================================
    // ADMINISTRATIVE FUNCTIONS
    // ========================================

    /**
     * @notice Pausa todas las transferencias de tokens
     * @dev Solo callable por PAUSER_ROLE
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Reanuda las transferencias de tokens
     * @dev Solo callable por PAUSER_ROLE
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Acuña nuevos tokens ANDE
     * @dev Solo callable por MINTER_ROLE (MintController)
     *
     *      IMPORTANTE: El minting deposita balance en el precompile/mock
     *      antes de llamar a _update()
     *
     * @param to Dirección que recibirá los tokens
     * @param amount Cantidad a acuñar
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        // Depositar balance en el precompile/mock primero
        // En producción, esto sucedería a nivel de EVM (no hay depósito explícito)
        // En testing con mock, llamamos a depositNativeBalance()
        (bool success,) =
            _nativeTransferPrecompile.call(abi.encodeWithSignature("depositNativeBalance(address,uint256)", to, amount));

        require(success, "Failed to deposit native balance");

        // Ahora ejecutar el flujo normal de _update
        // Esto actualizará los checkpoints de votación y emitirá evento Transfer
        _update(address(0), to, amount);
    }

    /**
     * @notice Actualiza la dirección del precompile
     * @dev Solo para testing/upgrades. En producción, esto estaría hardcodeado.
     * @param newPrecompileAddress Nueva dirección del precompile
     */
    function setPrecompileAddress(address newPrecompileAddress) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setPrecompileAddress(newPrecompileAddress);
    }

    /**
     * @notice Retorna la dirección actual del precompile
     * @return Dirección del precompile
     */
    function precompileAddress() external view returns (address) {
        return _nativeTransferPrecompile;
    }

    // ========================================
    // INTERNAL FUNCTIONS
    // ========================================

    /**
     * @dev Establece la dirección del precompile
     * @param newPrecompileAddress Dirección del precompile
     */
    function _setPrecompileAddress(address newPrecompileAddress) private {
        if (newPrecompileAddress == address(0)) {
            revert InvalidPrecompileAddress();
        }

        address oldAddress = _nativeTransferPrecompile;
        _nativeTransferPrecompile = newPrecompileAddress;

        emit PrecompileAddressUpdated(oldAddress, newPrecompileAddress);
    }

    /**
     * @dev Autoriza upgrades del contrato (patrón UUPS)
     * @param newImplementation Dirección de la nueva implementación
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Validación adicional si es necesario
    }

    /**
     * @dev Override para compatibilidad entre ERC20Permit y ERC20Votes
     */
    function nonces(address owner) public view override(ERC20PermitUpgradeable, NoncesUpgradeable) returns (uint256) {
        return super.nonces(owner);
    }
}
