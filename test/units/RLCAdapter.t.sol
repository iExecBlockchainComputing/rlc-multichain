// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCMock} from "./mocks/RLCMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {IexecLayerZeroBridge} from "../../src/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../src/DualPausableUpgradeable.sol";
import {TestUtils} from "./utils/TestUtils.sol";

contract RLCAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    RLCAdapter private adapter;
    IexecLayerZeroBridge private layerZeroBridgeMock;
    RLCMock private rlcToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
    string private name = "RLC Token";
    string private symbol = "RLC";

    // ============ EVENTS ============
    event EntrancePaused(address account);
    event EntranceUnpaused(address account);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointAdapter = address(endpoints[SOURCE_EID]);
        address lzEndpointBridge = address(endpoints[DEST_EID]);

        (adapter, layerZeroBridgeMock, rlcToken,) =
            TestUtils.setupDeployment(name, symbol, lzEndpointAdapter, lzEndpointBridge, owner, pauser);

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(adapter);
        contracts[1] = address(layerZeroBridgeMock);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint RLC tokens to user1
        rlcToken.transfer(user1, INITIAL_BALANCE);
        vm.prank(user1);
        rlcToken.approve(address(adapter), INITIAL_BALANCE);
    }

    // ============ BASIC ADAPTER FUNCTIONALITY TESTS ============

    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(adapter)), TRANSFER_AMOUNT);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============

    function test_Pause_EmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        vm.prank(pauser);
        adapter.pause();
    }

    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        adapter.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the adapter
        vm.prank(pauser);
        adapter.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were locked
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);
    }

    function test_RevertWhenSendRlcWithBridgePaused() public {
        // Pause the adapter
        vm.prank(pauser);
        adapter.pause();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - no tokens should be locked
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the adapter
        vm.startPrank(pauser);
        adapter.pause();

        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);
        adapter.unpause();
        vm.stopPrank();

        // Should now work normally
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceAdapterUnpaused() public {
        // Pause then unpause the adapter
        vm.startPrank(pauser);
        adapter.pause();
        adapter.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(adapter)), TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Entrance Pause) ============

    function test_PauseEntrances_EmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit EntrancePaused(pauser);

        vm.prank(pauser);
        adapter.pauseEntrances();
    }

    function test_PauseEntrances_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        adapter.pauseEntrances();
    }

    function test_PauseEntrances_BlocksOutgoingOnly() public {
        // Pause entrances
        vm.prank(pauser);
        adapter.pauseEntrances();

        // Verify state
        assertFalse(adapter.paused());
        assertTrue(adapter.entrancesPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedEntrancePause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedEntrancePause.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were locked
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);
    }

    function test_PauseEntrances_CannotPauseWhenFullyPaused() public {
        // First fully pause
        vm.prank(pauser);
        adapter.pause();

        // Attempt to pause entrances - should revert
        vm.prank(pauser);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.pauseEntrances();
    }

    function test_UnpauseEntrances_RestoresOutgoingTransfers() public {
        // Pause then unpause entrances
        vm.startPrank(pauser);
        adapter.pauseEntrances();

        vm.expectEmit(true, false, false, false);
        emit EntranceUnpaused(pauser);
        adapter.unpauseEntrances();
        vm.stopPrank();

        // Should now work normally
        assertFalse(adapter.paused());
        assertFalse(adapter.entrancesPaused());

        test_SendToken_WhenOperational();
    }

    // ============ DUAL PAUSE WORKFLOW TESTS ============

    function test_DualPause_EscalateFromEntranceToFull() public {
        // Start with entrance pause
        vm.startPrank(pauser);
        adapter.pauseEntrances();
        assertTrue(adapter.entrancesPaused());

        // Escalate to full pause - should reset entrance pause and emit events
        vm.expectEmit(true, false, false, false);
        emit EntranceUnpaused(pauser);
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        adapter.pause();
        vm.stopPrank();

        assertTrue(adapter.paused());
        assertFalse(adapter.entrancesPaused());
    }

    function test_DualPause_UnpauseFromFullRestoresOperational() public {
        vm.startPrank(pauser);

        // Go through: operational -> entrance pause -> full pause -> operational
        adapter.pauseEntrances();
        adapter.pause();
        adapter.unpause();
        vm.stopPrank();

        // Should be fully operational
        assertFalse(adapter.paused());
        assertFalse(adapter.entrancesPaused());
    }

    function test_PauseState_ReturnsCorrectStates() public {
        // Test pauseState function if it exists (it should based on the bridge contract)
        // Note: You'll need to add this function to RLCAdapter contract

        // Initially operational
        assertFalse(adapter.paused());
        assertFalse(adapter.entrancesPaused());

        // After entrance pause
        vm.prank(pauser);
        adapter.pauseEntrances();

        assertFalse(adapter.paused());
        assertTrue(adapter.entrancesPaused());

        // After full pause
        vm.prank(pauser);
        adapter.pause();

        assertTrue(adapter.paused());
        assertFalse(adapter.entrancesPaused()); // Reset when fully paused
    }

    // ============ EDGE CASE TESTS ============

    function test_PauseEntrances_CannotUnpauseWhenFullyPaused() public {
        vm.startPrank(pauser);

        // Pause entrances then full pause
        adapter.pauseEntrances();
        adapter.pause();

        // Attempt to unpause entrances while fully paused - should revert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.unpauseEntrances();

        vm.stopPrank();
    }

    function test_PauseEntrances_CannotUnpauseWhenNotPaused() public {
        // Attempt to unpause entrances when not paused
        vm.prank(pauser);
        vm.expectRevert(DualPausableUpgradeable.ExpectedEntrancesPause.selector);
        adapter.unpauseEntrances();
    }

    function test_PauseEntrances_CannotPauseTwice() public {
        // Pause entrances once
        vm.prank(pauser);
        adapter.pauseEntrances();

        // Try to pause again - should revert
        vm.prank(pauser);
        vm.expectRevert(DualPausableUpgradeable.EnforcedEntrancePause.selector);
        adapter.pauseEntrances();
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
