// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCOFTMock, Deploy as RLCOFTDeploy} from "./mocks/RLCOFTMock.sol";

contract RLCOFTTest is Test {
    RLCOFTMock public rlcOft;

    address public owner = makeAddr("owner");
    address public bridge = makeAddr("bridge");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public spender = makeAddr("spender");

    // Test constants
    uint32 public constant DESTINATION_EID = 40161; // Ethereum mainnet EID
    uint256 public constant TRANSFER_AMOUNT = 100 * 10 ** 9;
    uint256 public constant MINT_AMOUNT = 1000 * 10 ** 9;

    // Events to test
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Custom errors from OpenZeppelin and LayerZero
    error EnforcedPause();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        // Set up endpoints for the deployment
        address lzEndointOFT = 0x6EDCE65403992e310A62460808c4b910D972f10f;

        // Deploy RLCOFT
        rlcOft = RLCOFTMock(new RLCOFTDeploy().run(lzEndointOFT, owner, pauser));

        vm.startPrank(owner);
        rlcOft.grantRole(rlcOft.BRIDGE_ROLE(), bridge);
        vm.stopPrank();

        vm.startPrank(bridge);
        rlcOft.mint(user1, MINT_AMOUNT);
        rlcOft.mint(user2, 500 * 10 ** 9);
        vm.stopPrank();
    }

    // ============ Pausable Tests ============
    function test_PauseByPauser() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        vm.prank(pauser);
        rlcOft.pause();

        assertTrue(rlcOft.paused());
    }

    function test_RevertwhenPausedByUnauthorizedSender() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.PAUSER_ROLE()));
        vm.prank(user1);
        rlcOft.pause();
    }

    function test_UnpauseByPauser() public {
        // First pause
        vm.prank(pauser);
        rlcOft.pause();
        assertTrue(rlcOft.paused());

        // Then unpause
        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);

        vm.prank(pauser);
        rlcOft.unpause();

        assertFalse(rlcOft.paused());
    }

    function test_UnpauseUnauthorized() public {
        vm.prank(pauser);
        rlcOft.pause();

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.PAUSER_ROLE()));
        vm.prank(user1);
        rlcOft.unpause();
    }

    // ============ ERC20 Pausable Tests ============
    function test_RevertWhenTransferDuringPause() public {
        // TODO
    }

    function test_TransferFromWhenPaused() public {
        // TODO
    }

    function test_MintWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to mint - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.mint(user1, TRANSFER_AMOUNT);
    }

    function test_BurnWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to burn - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.burn(TRANSFER_AMOUNT);
    }

    function test_TransferWhenNotPaused() public {
        uint256 initialBalance1 = rlcOft.balanceOf(user1);
        uint256 initialBalance2 = rlcOft.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, TRANSFER_AMOUNT);

        vm.prank(user1);
        bool success = rlcOft.transfer(user2, TRANSFER_AMOUNT);

        assertTrue(success);
        assertEq(rlcOft.balanceOf(user1), initialBalance1 - TRANSFER_AMOUNT);
        assertEq(rlcOft.balanceOf(user2), initialBalance2 + TRANSFER_AMOUNT);
    }

    // ============ OFT Pausable Tests ============
    function test_LzReceiveWhenPaused() public {
        // Set up the peer to avoid NoPeer revert
        vm.prank(owner);
        rlcOft.setPeer(DESTINATION_EID, bytes32(uint256(uint160(address(rlcOft)))));

        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Create mock origin data
        Origin memory origin =
            Origin({srcEid: DESTINATION_EID, sender: bytes32(uint256(uint160(address(rlcOft)))), nonce: 1});

        // Create mock message data
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(user2))), // to address
            uint64(TRANSFER_AMOUNT / (10 ** (rlcOft.decimals() - rlcOft.sharedDecimals()))),
            bytes("")
        );

        bytes32 guid = keccak256("test_guid");

        // Mock the endpoint to call _lzReceive
        vm.prank(address(rlcOft.endpoint()));
        vm.expectRevert(EnforcedPause.selector);

        // This should revert with EnforcedPause due to contract being paused
        rlcOft.lzReceive(origin, guid, message, address(0), "");
    }

    // ============ Bridge Role Tests ============
    function test_MintByBridge() public {
        uint256 initialBalance = rlcOft.balanceOf(user1);
        uint256 initialTotalSupply = rlcOft.totalSupply();

        vm.prank(bridge);
        rlcOft.mint(user1, TRANSFER_AMOUNT);

        assertEq(rlcOft.balanceOf(user1), initialBalance + TRANSFER_AMOUNT);
        assertEq(rlcOft.totalSupply(), initialTotalSupply + TRANSFER_AMOUNT);
    }

    function test_BurnByBridge() public {
        uint256 initialBalance = rlcOft.balanceOf(bridge);
        uint256 initialTotalSupply = rlcOft.totalSupply();

        // First mint some tokens to bridge
        vm.prank(bridge);
        rlcOft.mint(bridge, TRANSFER_AMOUNT);

        // Then burn them
        vm.prank(bridge);
        rlcOft.burn(TRANSFER_AMOUNT);

        assertEq(rlcOft.balanceOf(bridge), initialBalance);
        assertEq(rlcOft.totalSupply(), initialTotalSupply);
    }

    function test_MintUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.BRIDGE_ROLE()));
        vm.prank(user1);
        rlcOft.mint(user1, TRANSFER_AMOUNT);
    }

    function test_BurnUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.BRIDGE_ROLE()));
        vm.prank(user1);
        rlcOft.burn(TRANSFER_AMOUNT);
    }
}
