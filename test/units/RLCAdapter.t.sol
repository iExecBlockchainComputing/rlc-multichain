// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Test, console} from "forge-std/Test.sol";
import {RLCAdapterTestSetup} from "./utils/RLCAdapterTestSetup.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";

contract RLCAdapterTest is RLCAdapterTestSetup, Initializable {
    RLCAdapter public rlcAdapter;

    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test constants
    uint32 public constant DESTINATION_EID = 40161; // Ethereum mainnet EID
    uint256 public constant TRANSFER_AMOUNT = 100 * 10 ** 9;
    uint256 public constant MINT_AMOUNT = 1000 * 10 ** 9;

    // Events to test
    event Paused(address account);
    event Unpaused(address account);

    // Custom errors from OpenZeppelin and LayerZero
    error EnforcedPause();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        // Set up environment variables for the deployment
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");

        // Deploy the contract using the deployment script
        rlcAdapter = RLCAdapter(_forkSepoliaAndDeploy());
    }

    // ============ Pausable Tests ============
    function test_PauseByPauser() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        vm.prank(pauser);
        rlcAdapter.pause();

        assertTrue(rlcAdapter.paused());
    }

    function test_RevertwhenPausedByUnauthorizedSender() public {
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcAdapter.PAUSER_ROLE())
        );
        vm.prank(user1);
        rlcAdapter.pause();
    }

    function test_UnpauseByPauser() public {
        // First pause
        vm.prank(pauser);
        rlcAdapter.pause();
        assertTrue(rlcAdapter.paused());

        // Then unpause
        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);

        vm.prank(pauser);
        rlcAdapter.unpause();

        assertFalse(rlcAdapter.paused());
    }

    function test_UnpauseUnauthorized() public {
        vm.prank(pauser);
        rlcAdapter.pause();

        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcAdapter.PAUSER_ROLE())
        );
        vm.prank(user1);
        rlcAdapter.unpause();
    }

    // ============ Adapter Pausable Tests ============
    function test_LzReceiveWhenPaused() public {
        // Set up the peer to avoid NoPeer revert
        vm.prank(owner);
        rlcAdapter.setPeer(DESTINATION_EID, bytes32(uint256(uint160(address(rlcAdapter)))));

        // Pause the contract using PAUSER_ROLE
        vm.prank(pauser);
        rlcAdapter.pause();

        // Create mock origin data
        Origin memory origin =
            Origin({srcEid: DESTINATION_EID, sender: bytes32(uint256(uint160(address(rlcAdapter)))), nonce: 1});

        // Create mock message data
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(user2))), // to address
            uint64(TRANSFER_AMOUNT / (10 ** (9 - rlcAdapter.sharedDecimals()))), // Using 9 decimals for RLC
            bytes("")
        );

        bytes32 guid = keccak256("test_guid");

        // Mock the endpoint to call lzReceive (which internally calls _lzReceive)
        vm.prank(address(rlcAdapter.endpoint()));
        vm.expectRevert(EnforcedPause.selector);

        // This should revert with EnforcedPause due to contract being paused
        rlcAdapter.lzReceive(origin, guid, message, address(0), "");
    }
}
