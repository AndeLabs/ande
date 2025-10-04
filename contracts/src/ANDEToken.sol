// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20PermitUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20VotesUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title ANDEToken
 * @author Ande Labs
 * @notice Este es el contrato para el token $ANDE, el activo nativo y de gobernanza del ecosistema AndeChain.
 * @dev Implementa los estándares ERC20, Permit (EIP-2612), y Votes (EIP-6372) para la gobernanza.
 * Es actualizable (UUPS), pausable y utiliza AccessControl para una gestión de roles granular.
 */
contract ANDEToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ERC20PermitUpgradeable,
    ERC20VotesUpgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable
{
    /// @notice Rol para acuñar nuevos tokens. Asignado al MintController.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Rol para pausar y reanudar las transferencias de tokens en caso de emergencia.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa el contrato después de su despliegue (patrón de proxy).
     * @param defaultAdmin La dirección que tendrá el rol de administrador por defecto (para gobernanza y actualizaciones).
     * @param minter La dirección del contrato (MintController) que tendrá el permiso para acuñar nuevos tokens.
     */
    function initialize(address defaultAdmin, address minter) public initializer {
        __ERC20_init("ANDE Token", "ANDE");
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ERC20Permit_init("ANDE Token");
        __ERC20Votes_init();
        __ERC20Burnable_init();
        __Pausable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(PAUSER_ROLE, defaultAdmin);
    }

    /**
     * @notice Pausa todas las transferencias de tokens. Solo puede ser llamado por una cuenta con `PAUSER_ROLE`.
     * @dev Útil como medida de seguridad de emergencia.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Reanuda las transferencias de tokens si estaban pausadas. Solo puede ser llamado por una cuenta con `PAUSER_ROLE`.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice Acuña una nueva cantidad de tokens y los asigna a una dirección.
     * @dev Protegido por `MINTER_ROLE` y no se puede ejecutar si el contrato está pausado.
     * @param to La dirección que recibirá los nuevos tokens.
     * @param amount La cantidad de tokens a acuñar.
     */
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) whenNotPaused {
        _mint(to, amount);
    }

    /**
     * @dev Autoriza una actualización del contrato (patrón UUPS). Solo el `DEFAULT_ADMIN_ROLE` puede autorizar.
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {
        // La implementación de UUPS de OpenZeppelin v5 ya no requiere una vista (view).
        // Dejar el cuerpo vacío es suficiente si no se necesita lógica de autorización adicional.
    }

    /**
     * @dev Requerido para la compatibilidad entre ERC20Permit y ERC20Votes.
     */
    function nonces(address owner)
        public
        view
        override(ERC20PermitUpgradeable, NoncesUpgradeable)
        returns (uint256)
    {
        return super.nonces(owner);
    }

    /**
     * @dev Hook interno que se ejecuta en cada transferencia, acuñación o quema de tokens.
     * @dev Se asegura de que las transferencias no ocurran mientras el contrato está pausado y actualiza los checkpoints de votación.
     */
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20Upgradeable, ERC20VotesUpgradeable, PausableUpgradeable)
    {
        super._update(from, to, value);
    }
}
