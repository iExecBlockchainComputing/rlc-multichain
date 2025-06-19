// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {RLCMock} from "./mocks/RLCMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {IexecLayerZeroBridge} from "../../src/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../src/DualPausableUpgradeable.sol";
import {TestUtils} from "./utils/TestUtils.sol";

contract IexecLayerZeroBridgeTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridge;
    RLCAdapter private adapterMock;
    RLCMock private rlcCrosschainToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
    string private name = "RLC Crosschain Token";
    string private symbol = "RLC";

    // ============ EVENTS ============
    event SendPaused(address account);
    event SendUnpaused(address account);
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointBridge = address(endpoints[SOURCE_EID]);
        address lzEndpointAdapter = address(endpoints[DEST_EID]);

        (adapterMock, iexecLayerZeroBridge,, rlcCrosschainToken) =
            TestUtils.setupDeployment(name, symbol, lzEndpointAdapter, lzEndpointBridge, owner, pauser);

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(iexecLayerZeroBridge);
        contracts[1] = address(adapterMock);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint RLC tokens to user1
        rlcCrosschainToken.crosschainMint(user1, INITIAL_BALANCE);
    }

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============

    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============

    function test_Pause_EmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        vm.prank(pauser);
        iexecLayerZeroBridge.pause();
    }

    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();

        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);
        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Should now work normally
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();
        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============

    function test_PauseSends_EmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit SendPaused(pauser);

        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();
    }

    function test_PauseSends_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pauseSend();
    }

    function test_PauseSends_BlocksOutgoingOnly() public {
        // Pause send
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();

        // Verify state
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_UnpauseSends_RestoresOutgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseSend();

        vm.expectEmit(true, false, false, false);
        emit SendUnpaused(pauser);
        iexecLayerZeroBridge.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.sendPaused());

        test_SendToken_WhenOperational();
    }

    // ============ DUAL PAUSE WORKFLOW TESTS ============

    function test_DualPause_PauseFromSendToFull() public {
        // Start with send pause
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseSend();
        assertTrue(iexecLayerZeroBridge.sendPaused());

        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        iexecLayerZeroBridge.pause();
        vm.stopPrank();

        assertTrue(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.sendPaused());
    }

    function test_PauseStatus_ReturnsCorrectStates() public {
        // Initially operational
        (bool fullyPaused, bool onlySendPaused) = iexecLayerZeroBridge.pauseStatus();
        assertFalse(fullyPaused);
        assertFalse(onlySendPaused);

        // After send pause
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();

        (fullyPaused, onlySendPaused) = iexecLayerZeroBridge.pauseStatus();
        assertFalse(fullyPaused);
        assertTrue(onlySendPaused);

        // After full pause
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        (fullyPaused, onlySendPaused) = iexecLayerZeroBridge.pauseStatus();
        assertTrue(fullyPaused);
        assertTrue(onlySendPaused);
    }

    // ============ EDGE CASE TESTS ============

    function test_PauseSends_CannotUnpauseWhenNotPaused() public {
        // Attempt to unpause send when not paused
        vm.prank(pauser);
        vm.expectRevert(DualPausableUpgradeable.ExpectedSendPause.selector);
        iexecLayerZeroBridge.unpauseSend();
    }

    function test_PauseSends_CannotPauseTwice() public {
        // Pause send once
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();

        // Try to pause again - should revert
        vm.prank(pauser);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridge.pauseSend();
    }

    function test_Pause_CannotPauseTwice() public {
        // Pause once
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Try to pause again - should revert
        vm.prank(pauser);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.pause();
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
