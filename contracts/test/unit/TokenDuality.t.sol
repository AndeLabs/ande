// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console2} from "forge-std/Test.sol";
import {ANDETokenDuality} from "../../src/ANDETokenDuality.sol";
import {NativeTransferPrecompileMock} from "../../src/mocks/NativeTransferPrecompileMock.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title TokenDualityTest
 * @notice Suite completa de tests para verificar Token Duality
 *
 * @dev Tests organizados por categoría:
 *      1. Core Token Duality
 *      2. ERC-20 Standard Compliance
 *      3. ERC-20 Votes (Gobernanza)
 *      4. ERC-20 Permit (Gasless Approvals)
 *      5. Pausable
 *      6. Access Control
 *      7. Minting
 *      8. Integration Tests
 */
contract TokenDualityTest is Test {
    // ========================================
    // STATE VARIABLES
    // ========================================

    ANDETokenDuality public ande;
    NativeTransferPrecompileMock public precompileMock;

    address public owner;
    address public alice;
    address public bob;
    address public charlie;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // ========================================
    // SETUP
    // ========================================

    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");

        // Deploy implementation
        ANDETokenDuality implementation = new ANDETokenDuality();

        // Deploy mock precompile con placeholder address temporal
        address placeholder = address(0x1234); // Placeholder temporal
        precompileMock = new NativeTransferPrecompileMock(placeholder);

        // Deploy proxy con initialize
        bytes memory initData =
            abi.encodeWithSelector(ANDETokenDuality.initialize.selector, owner, owner, address(precompileMock));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        ande = ANDETokenDuality(address(proxy));

        // Crear nuevo mock con el authorized caller correcto (el proxy)
        precompileMock = new NativeTransferPrecompileMock(address(ande));

        // Actualizar dirección del precompile en el token
        vm.prank(owner);
        ande.setPrecompileAddress(address(precompileMock));

        // Mint inicial para Alice
        vm.prank(owner);
        ande.mint(alice, 1000 ether);
    }

    // ========================================
    // CATEGORY 1: CORE TOKEN DUALITY
    // ========================================

    function test_BalanceOfReadsFromPrecompile() public view {
        // balanceOf() debe consultar al precompile, no a storage
        uint256 balance = ande.balanceOf(alice);
        assertEq(balance, 1000 ether, "Balance should be read from precompile");

        // Verificar que coincide con balance nativo del mock
        uint256 nativeBalance = precompileMock.getNativeBalance(alice);
        assertEq(balance, nativeBalance, "ERC20 balance should match native balance");
    }

    function test_TotalSupplyReadsFromPrecompile() public view {
        uint256 supply = ande.totalSupply();
        assertEq(supply, 1000 ether, "Total supply should be read from precompile");

        uint256 nativeSupply = precompileMock.totalSupply();
        assertEq(supply, nativeSupply, "ERC20 supply should match native supply");
    }

    function test_TransferUpdatesNativeBalance() public {
        uint256 transferAmount = 100 ether;

        uint256 aliceBalanceBefore = precompileMock.getNativeBalance(alice);
        uint256 bobBalanceBefore = precompileMock.getNativeBalance(bob);

        vm.prank(alice);
        ande.transfer(bob, transferAmount);

        // Verificar que balances nativos cambiaron
        assertEq(precompileMock.getNativeBalance(alice), aliceBalanceBefore - transferAmount);
        assertEq(precompileMock.getNativeBalance(bob), bobBalanceBefore + transferAmount);
    }

    function test_TransferEmitsEvent() public {
        uint256 transferAmount = 50 ether;

        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, transferAmount);

        ande.transfer(bob, transferAmount);
    }

    function test_PrecompileAddressIsConfigurable() public {
        address newMockAddress = makeAddr("newMock");

        vm.prank(owner);
        vm.expectEmit(true, true, false, false);
        emit PrecompileAddressUpdated(address(precompileMock), newMockAddress);

        ande.setPrecompileAddress(newMockAddress);

        assertEq(ande.precompileAddress(), newMockAddress);
    }

    function test_RevertWhen_SetPrecompileAddressNotAdmin() public {
        vm.prank(alice);
        vm.expectRevert();
        ande.setPrecompileAddress(makeAddr("unauthorized"));
    }

    // ========================================
    // CATEGORY 2: ERC-20 STANDARD COMPLIANCE
    // ========================================

    function test_Transfer() public {
        uint256 amount = 100 ether;

        vm.prank(alice);
        bool success = ande.transfer(bob, amount);

        assertTrue(success);
        assertEq(ande.balanceOf(alice), 900 ether);
        assertEq(ande.balanceOf(bob), amount);
    }

    function test_Approve() public {
        uint256 amount = 500 ether;

        vm.prank(alice);
        bool success = ande.approve(bob, amount);

        assertTrue(success);
        assertEq(ande.allowance(alice, bob), amount);
    }

    function test_TransferFrom() public {
        uint256 approvalAmount = 500 ether;
        uint256 transferAmount = 100 ether;

        // Alice aprueba a Bob
        vm.prank(alice);
        ande.approve(bob, approvalAmount);

        // Bob transfiere de Alice a Charlie
        vm.prank(bob);
        bool success = ande.transferFrom(alice, charlie, transferAmount);

        assertTrue(success);
        assertEq(ande.balanceOf(alice), 900 ether);
        assertEq(ande.balanceOf(charlie), transferAmount);
        assertEq(ande.allowance(alice, bob), approvalAmount - transferAmount);
    }

    function test_RevertWhen_TransferInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert();  // Precompile debería revertir con InsufficientBalance
        ande.transfer(bob, 2000 ether);  // Alice solo tiene 1000
    }

    function test_RevertWhen_TransferFromInsufficientAllowance() public {
        // Bob NO tiene allowance
        vm.prank(bob);
        vm.expectRevert();
        ande.transferFrom(alice, charlie, 100 ether);
    }

    function test_TransferZeroAmount() public {
        // Transferir 0 debería funcionar (gas saving en precompile)
        vm.prank(alice);
        bool success = ande.transfer(bob, 0);

        assertTrue(success);
        assertEq(ande.balanceOf(alice), 1000 ether);  // Sin cambios
        assertEq(ande.balanceOf(bob), 0);
    }

    // ========================================
    // CATEGORY 3: ERC-20 VOTES (GOBERNANZA)
    // ========================================

    function test_DelegateVotes() public {
        // Alice se delega a sí misma
        vm.prank(alice);
        ande.delegate(alice);

        assertEq(ande.getVotes(alice), 1000 ether, "Alice should have voting power");
    }

    function test_VotingPowerUpdatesOnTransfer() public {
        // Alice se delega a sí misma
        vm.prank(alice);
        ande.delegate(alice);

        uint256 votesBefore = ande.getVotes(alice);
        assertEq(votesBefore, 1000 ether);

        // Alice transfiere a Bob
        vm.prank(alice);
        ande.transfer(bob, 300 ether);

        // Votos de Alice deben disminuir
        uint256 votesAfter = ande.getVotes(alice);
        assertEq(votesAfter, 700 ether);

        // Bob aún no tiene votos (no se ha delegado)
        assertEq(ande.getVotes(bob), 0);
    }

    function test_DelegateToOtherAddress() public {
        // Alice delega a Bob
        vm.prank(alice);
        ande.delegate(bob);

        // Bob tiene el poder de voto de Alice
        assertEq(ande.getVotes(bob), 1000 ether);
        assertEq(ande.getVotes(alice), 0);
    }

    function test_VotesCheckpoint() public {
        // Block inicial (1)
        assertEq(block.number, 1);

        // Alice se delega
        vm.prank(alice);
        ande.delegate(alice);

        // Avanzar a block 2
        vm.roll(2);

        // Alice transfiere
        vm.prank(alice);
        ande.transfer(bob, 200 ether);

        // Avanzar a block 3
        vm.roll(3);

        // Verificar histórico de votos en block 1 (cuando se delegó)
        uint256 pastVotes = ande.getPastVotes(alice, 1);
        assertEq(pastVotes, 1000 ether, "Past votes at block 1 should be 1000");

        uint256 currentVotes = ande.getVotes(alice);
        assertEq(currentVotes, 800 ether, "Current votes should be 800");
    }

    // ========================================
    // CATEGORY 4: ERC-20 PERMIT (GASLESS APPROVALS)
    // ========================================

    function test_Permit() public {
        uint256 privateKey = 0xA11CE;
        address alicePermit = vm.addr(privateKey);

        // Mint para alice
        vm.prank(owner);
        ande.mint(alicePermit, 1000 ether);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = ande.nonces(alicePermit);
        uint256 amount = 500 ether;

        // Crear firma de permit
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                alicePermit,
                bob,
                amount,
                nonce,
                deadline
            )
        );

        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", ande.DOMAIN_SEPARATOR(), structHash));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);

        // Ejecutar permit
        ande.permit(alicePermit, bob, amount, deadline, v, r, s);

        // Verificar approval
        assertEq(ande.allowance(alicePermit, bob), amount);
    }

    // ========================================
    // CATEGORY 5: PAUSABLE
    // ========================================

    function test_PauseBlocksTransfers() public {
        vm.prank(owner);
        ande.pause();

        vm.prank(alice);
        vm.expectRevert();  // EnforcedPause
        ande.transfer(bob, 100 ether);
    }

    function test_UnpauseAllowsTransfers() public {
        // Pausar
        vm.prank(owner);
        ande.pause();

        // Reanudar
        vm.prank(owner);
        ande.unpause();

        // Ahora debe funcionar
        vm.prank(alice);
        ande.transfer(bob, 100 ether);

        assertEq(ande.balanceOf(bob), 100 ether);
    }

    function test_RevertWhen_PauseNotPauser() public {
        vm.prank(alice);
        vm.expectRevert();
        ande.pause();
    }

    // ========================================
    // CATEGORY 6: ACCESS CONTROL
    // ========================================

    function test_OnlyMinterCanMint() public {
        vm.prank(owner);
        ande.mint(bob, 500 ether);

        assertEq(ande.balanceOf(bob), 500 ether);
    }

    function test_RevertWhen_NonMinterMints() public {
        vm.prank(alice);
        vm.expectRevert();
        ande.mint(bob, 500 ether);
    }

    // ========================================
    // CATEGORY 7: MINTING
    // ========================================

    function test_MintIncreasesTotalSupply() public {
        uint256 supplyBefore = ande.totalSupply();
        uint256 mintAmount = 500 ether;

        vm.prank(owner);
        ande.mint(bob, mintAmount);

        assertEq(ande.totalSupply(), supplyBefore + mintAmount);
    }

    function test_MintUpdatesBalance() public {
        uint256 bobBalanceBefore = ande.balanceOf(bob);
        uint256 mintAmount = 500 ether;

        vm.prank(owner);
        ande.mint(bob, mintAmount);

        assertEq(ande.balanceOf(bob), bobBalanceBefore + mintAmount);
    }

    // ========================================
    // CATEGORY 8: INTEGRATION TESTS
    // ========================================

    function test_ComplexScenario_MultipleTransfers() public {
        // Escenario: Alice → Bob → Charlie → Alice (circular)

        // 1. Alice → Bob (300)
        vm.prank(alice);
        ande.transfer(bob, 300 ether);

        assertEq(ande.balanceOf(alice), 700 ether);
        assertEq(ande.balanceOf(bob), 300 ether);

        // 2. Bob → Charlie (100)
        vm.prank(bob);
        ande.transfer(charlie, 100 ether);

        assertEq(ande.balanceOf(bob), 200 ether);
        assertEq(ande.balanceOf(charlie), 100 ether);

        // 3. Charlie → Alice (50)
        vm.prank(charlie);
        ande.transfer(alice, 50 ether);

        assertEq(ande.balanceOf(charlie), 50 ether);
        assertEq(ande.balanceOf(alice), 750 ether);

        // Verificar total supply no cambió
        assertEq(ande.totalSupply(), 1000 ether);
    }

    function test_ComplexScenario_TransferWithVoting() public {
        // Escenario: Transferencias mientras se usa delegación

        // Alice y Bob se delegan a sí mismos
        vm.prank(alice);
        ande.delegate(alice);

        vm.prank(owner);
        ande.mint(bob, 500 ether);

        vm.prank(bob);
        ande.delegate(bob);

        // Verificar votos iniciales
        assertEq(ande.getVotes(alice), 1000 ether);
        assertEq(ande.getVotes(bob), 500 ether);

        // Alice transfiere a Bob
        vm.prank(alice);
        ande.transfer(bob, 200 ether);

        // Votos deben actualizarse
        assertEq(ande.getVotes(alice), 800 ether);
        assertEq(ande.getVotes(bob), 700 ether);
    }

    // ========================================
    // EVENTS
    // ========================================

    event Transfer(address indexed from, address indexed to, uint256 value);
    event PrecompileAddressUpdated(address indexed oldAddress, address indexed newAddress);
}
