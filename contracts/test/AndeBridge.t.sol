// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/Vm.sol";
import {AndeBridge} from "../src/AndeBridge.sol";
import {MockERC20} from "../src/mocks/MockERC20.sol";

contract AndeBridgeTest is Test {
    AndeBridge public andeBridge;
    MockERC20 public abobToken;

    address public user = address(1);
    address public recipient = address(2);

    function setUp() public {
        // Desplegar el token de prueba y el contrato de bridge
        abobToken = new MockERC20("Mock ABOB", "mABOB", 18);
        andeBridge = new AndeBridge(address(abobToken));

        // Darle al usuario algunos tokens para probar
        abobToken.mint(user, 1_000_000 * 10**18);
    }

    function test_BridgeInitiation() public {
        uint256 amount = 100 * 10**18;

        vm.startPrank(user);
        abobToken.approve(address(andeBridge), amount);

        // 1. Iniciar la grabación de logs
        vm.recordLogs();

        // 2. Ejecutar la función de bridge
        andeBridge.bridgeToEthereum(amount, recipient);

        // 3. Obtener los logs grabados
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // 4. Buscar y verificar el evento BridgeInitiated
        bytes32 eventSignature = keccak256("BridgeInitiated(address,address,uint256,uint256,bytes32)");
        bool eventFound = false;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == eventSignature) {
                eventFound = true;
                assertEq(address(uint160(uint256(entries[i].topics[1]))), user, "Sender mismatch");
                assertEq(address(uint160(uint256(entries[i].topics[2]))), recipient, "Recipient mismatch");

                (uint256 emittedAmount, uint256 emittedChainId, bytes32 emittedCommitment) = abi.decode(entries[i].data, (uint256, uint256, bytes32));
                assertEq(emittedAmount, amount, "Amount mismatch");
                assertEq(emittedChainId, block.chainid, "Chain ID mismatch");

                bytes32 expectedCommitment = keccak256(abi.encodePacked(user, recipient, amount, block.chainid, block.number));
                assertEq(emittedCommitment, expectedCommitment, "Commitment mismatch");
                break;
            }
        }
        assertTrue(eventFound, "BridgeInitiated event not found");

        vm.stopPrank();

        // Verificar que los tokens fueron transferidos al contrato de bridge
        assertEq(abobToken.balanceOf(user), (1_000_000 - 100) * 10**18);
        assertEq(abobToken.balanceOf(address(andeBridge)), amount);
    }

    function test_FailIfAmountIsZero() public {
        vm.startPrank(user);
        vm.expectRevert("Amount must be greater than zero");
        andeBridge.bridgeToEthereum(0, recipient);
        vm.stopPrank();
    }
}
