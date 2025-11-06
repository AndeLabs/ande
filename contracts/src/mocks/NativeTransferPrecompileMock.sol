// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title NativeTransferPrecompileMock
 * @author Ande Labs
 * @notice Mock del precompile de transferencia nativa para Token Duality
 *
 * @dev IMPORTANTE: Este es un MOCK para testing. En producción, esta lógica
 *      estará implementada como precompile en ev-reth en la dirección 0x...fd
 *
 * Este contrato simula el comportamiento del precompile real:
 * - Solo puede ser llamado por ANDEToken (authorized caller)
 * - Ejecuta transferencias "nativas" (simuladas con un mapping interno)
 * - Valida balance suficiente
 * - Retorna éxito/fallo igual que el precompile real
 *
 * @custom:security-contact security@andelabs.io
 */
contract NativeTransferPrecompileMock {
    // ========================================
    // STATE VARIABLES
    // ========================================

    /// @notice Dirección autorizada para llamar este contrato (ANDEToken)
    address public authorizedCaller;

    /// @notice Mapping que simula balances nativos
    /// @dev En producción, esto será address.balance real
    mapping(address => uint256) private _nativeBalances;

    /// @notice Total supply simulado
    uint256 private _totalSupply;

    // ========================================
    // EVENTS
    // ========================================

    /// @notice Emitido cuando se ejecuta una transferencia nativa simulada
    event NativeTransfer(address indexed from, address indexed to, uint256 value);

    /// @notice Emitido cuando se deposita balance nativo simulado
    event NativeDeposit(address indexed account, uint256 amount);

    // ========================================
    // ERRORS
    // ========================================

    error UnauthorizedCaller(address caller);
    error InsufficientBalance(address account, uint256 required, uint256 available);
    error InvalidInput(string reason);
    error TransferToZeroAddress();

    // ========================================
    // CONSTRUCTOR
    // ========================================

    /**
     * @notice Inicializa el mock con la dirección autorizada
     * @param _authorizedCaller Dirección del contrato ANDEToken (puede ser address(0) si se configura después)
     */
    constructor(address _authorizedCaller) {
        authorizedCaller = _authorizedCaller;
    }

    /**
     * @notice Configura el authorized caller después del deploy
     * @dev Solo puede ser llamado una vez si authorizedCaller es address(0)
     * @param _authorizedCaller Nueva dirección autorizada
     */
    function setAuthorizedCaller(address _authorizedCaller) external {
        require(authorizedCaller == address(0), "Authorized caller already set");
        require(_authorizedCaller != address(0), "Cannot set to zero address");
        authorizedCaller = _authorizedCaller;
    }

    // ========================================
    // EXTERNAL FUNCTIONS - SIMULATING PRECOMPILE
    // ========================================

    /**
     * @notice Simula el precompile de transferencia nativa
     * @dev Esta función replica el comportamiento del precompile real en ev-reth
     *
     * Formato de entrada (ABI encoded):
     * - from: address (32 bytes, últimos 20 bytes son la dirección)
     * - to: address (32 bytes, últimos 20 bytes son la dirección)
     * - value: uint256 (32 bytes)
     *
     * @param input Datos codificados en ABI: (address from, address to, uint256 value)
     * @return output Datos de retorno (bytes32(1) para éxito)
     */
    function _executeTransfer(bytes calldata input) internal returns (bytes memory output) {
        // 1. VALIDACIÓN DE CALLER
        if (msg.sender != authorizedCaller) {
            revert UnauthorizedCaller(msg.sender);
        }

        // 2. DECODIFICACIÓN DE INPUT
        if (input.length != 96) {
            revert InvalidInput("Input must be exactly 96 bytes (3 x 32)");
        }

        // Decodificar parámetros usando abi.decode
        (address from, address to, uint256 value) = abi.decode(input, (address, address, uint256));

        // 3. VALIDACIONES DE NEGOCIO
        if (to == address(0)) {
            revert TransferToZeroAddress();
        }

        // Si value es 0, retornar éxito sin hacer nada (gas saving)
        if (value == 0) {
            return abi.encode(uint256(1));
        }

        // 4. VERIFICAR BALANCE SUFICIENTE
        uint256 fromBalance = _nativeBalances[from];
        if (fromBalance < value) {
            revert InsufficientBalance(from, value, fromBalance);
        }

        // 5. EJECUTAR TRANSFERENCIA
        unchecked {
            // Safe porque verificamos balance arriba
            _nativeBalances[from] = fromBalance - value;
            _nativeBalances[to] += value;
        }

        // 6. EMITIR EVENTO
        emit NativeTransfer(from, to, value);

        // 7. RETORNAR ÉXITO
        return abi.encode(uint256(1));
    }

    // ========================================
    // HELPER FUNCTIONS - SOLO PARA TESTING
    // ========================================

    /**
     * @notice Deposita balance nativo simulado a una cuenta
     * @dev Solo para testing. En producción, el balance nativo viene del genesis/mining
     * @param account Dirección a la que depositar
     * @param amount Cantidad a depositar
     */
    function depositNativeBalance(address account, uint256 amount) external {
        // Validar que solo el ANDEToken puede llamar esta función
        if (msg.sender != authorizedCaller) {
            revert UnauthorizedCaller(msg.sender);
        }
        require(account != address(0), "Cannot deposit to zero address");
        _nativeBalances[account] += amount;
        _totalSupply += amount;
        emit NativeDeposit(account, amount);
    }

    /**
     * @notice Retorna el balance nativo simulado de una cuenta
     * @dev En producción, esto sería address.balance
     * @param account Dirección a consultar
     * @return Balance nativo simulado
     */
    function getNativeBalance(address account) external view returns (uint256) {
        return _nativeBalances[account];
    }

    /**
     * @notice Retorna el total supply simulado
     * @return Total supply de balances nativos
     */
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // ========================================
    // FALLBACK - SIMULA COMPORTAMIENTO DE PRECOMPILE
    // ========================================

    /**
     * @notice Fallback que acepta cualquier call y lo procesa como transferencia nativa
     * @dev Esto simula cómo un precompile real recibe llamadas arbitrarias
     */
    fallback(bytes calldata input) external returns (bytes memory) {
        return _executeTransfer(input);
    }

    /**
     * @notice No acepta ETH directo
     */
    receive() external payable {
        revert("Precompile mock does not accept ETH");
    }
}
