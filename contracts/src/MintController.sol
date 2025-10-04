// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AccessControlUpgradeable} from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {VeANDE} from "./VeANDE.sol";

interface IMintable is IERC20 {
    function mint(address to, uint256 amount) external;
}

/**
 * @title MintController
 * @author Ande Labs
 * @notice Contrato de gobernanza para controlar la acuñación (minting) de nuevos tokens $ANDE.
 * @dev Implementa un sistema de propuestas con votación, quórum, supermayoría y timelock para garantizar
 * un proceso de emisión de tokens seguro, descentralizado y predecible.
 */
contract MintController is
    Initializable,
    AccessControlUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IMintable;

    // --- Roles ---
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    // --- State ---
    IMintable public andeToken;
    VeANDE public veANDE;

    // --- Parámetros Económicos ---
    uint256 public hardCap;
    uint256 public totalMinted;
    uint256 public annualMintLimit;
    uint256 public lastMintYear;
    uint256 public mintedThisYear;

    // --- Parámetros de Gobernanza ---
    uint256 public constant SUPERMAJORITY_THRESHOLD = 7500; // 75% en puntos básicos
    uint256 public constant BASIS_POINTS = 10000;
    uint256 public quorumPercentage;
    uint256 public votingPeriod;
    uint256 public executionDelay; // Timelock
    uint256 public proposalLifetime;

    // --- Propuestas ---
    enum ProposalState { Pending, Active, Defeated, Succeeded, Queued, Executed, Cancelled, Expired }
    struct MintProposal {
        uint256 amount;
        address recipient;
        uint256 snapshotBlock;
        uint256 creationTime;
        uint256 votingDeadline;
        uint256 executionETA;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 totalVotingPowerAtSnapshot;
        bool executed;
        bool cancelled;
        string description;
        mapping(address => bool) hasVoted;
    }
    mapping(uint256 => MintProposal) public proposals;
    uint256 public proposalCount;

    // --- Límites de Propuestas ---
    uint256 public maxProposalAmount;
    uint256 public minProposalAmount;

    // --- Errores ---
    error InvalidTokenAddress();
    error InvalidVeANDEAddress();
    // ... (y otros errores)

    // --- Eventos ---
    event ProposalCreated(uint256 indexed proposalId, uint256 amount, address indexed recipient, uint256 snapshotBlock, uint256 votingDeadline, string description);
    // ... (y otros eventos)

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Inicializa el MintController.
     * @param defaultAdmin Dirección del administrador principal.
     * @param governance Dirección del contrato de gobernanza o wallet que puede crear propuestas.
     * @param guardian Dirección que puede pausar el contrato en emergencias.
     * @param _andeToken Dirección del contrato ANDEToken.
     * @param _veANDE Dirección del contrato VeANDE.
     * @param _hardCap Límite máximo absoluto de tokens $ANDE que pueden existir.
     * @param _annualMintLimit Límite de tokens que se pueden acuñar por año.
     */
    function initialize(...) public initializer {
        // ...
    }

    /**
     * @notice Crea una nueva propuesta para acuñar tokens.
     * @dev Solo puede ser llamado por una cuenta con `GOVERNANCE_ROLE`.
     * @param amount Cantidad de tokens a acuñar.
     * @param recipient Dirección que recibirá los tokens.
     * @param description Descripción legible de la propuesta.
     * @return El ID de la nueva propuesta.
     */
    function createProposal(...) external returns (uint256) {
        // ...
    }

    /**
     * @notice Emite un voto en una propuesta activa.
     * @param proposalId El ID de la propuesta.
     * @param support `true` para votar a favor, `false` para votar en contra.
     */
    function castVote(uint256 proposalId, bool support) external {
        // ...
    }

    /**
     * @notice Pone en cola una propuesta que ha sido aprobada para su futura ejecución.
     * @dev Activa el timelock (`executionDelay`).
     * @param proposalId El ID de la propuesta.
     */
    function queueProposal(uint256 proposalId) external {
        // ...
    }

    /**
     * @notice Ejecuta una propuesta que ha sido aprobada y ha cumplido su período de timelock.
     * @dev Solo puede ser llamado por `GOVERNANCE_ROLE`. Acuña y transfiere los tokens.
     * @param proposalId El ID de la propuesta.
     */
    function executeProposal(uint256 proposalId) external {
        // ...
    }

    // ... (resto de funciones documentadas de manera similar)
}