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
    event EntrancePaused(address account);
    event EntranceUnpaused(address account);
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

    function test_RevertWhenSendRlcWithBridgePaused() public {
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - no tokens should be burned
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

    // ============ LEVEL 2 PAUSE TESTS (Entrance Pause) ============

    function test_PauseEntrances_EmitsCorrectEvent() public {
        vm.expectEmit(true, false, false, false);
        emit EntrancePaused(pauser);

        vm.prank(pauser);
        iexecLayerZeroBridge.pauseEntrances();
    }

    function test_PauseEntrances_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pauseEntrances();
    }

    function test_PauseEntrances_BlocksOutgoingOnly() public {
        // Pause entrances
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseEntrances();

        // Verify state
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.entrancesPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EntrancesPaused
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EntrancesPaused.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_PauseEntrances_CannotPauseWhenFullyPaused() public {
        // First fully pause
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Attempt to pause entrances - should revert
        vm.prank(pauser);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.pauseEntrances();
    }

    function test_UnpauseEntrances_RestoresOutgoingTransfers() public {
        // Pause then unpause entrances
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseEntrances();
        
        vm.expectEmit(true, false, false, false);
        emit EntranceUnpaused(pauser);
        iexecLayerZeroBridge.unpauseEntrances();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.entrancesPaused());
        
        test_SendToken_WhenOperational();
    }

    // ============ DUAL PAUSE WORKFLOW TESTS ============

    function test_DualPause_EscalateFromEntranceToFull() public { // fails
        // Start with entrance pause
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseEntrances();
        assertTrue(iexecLayerZeroBridge.entrancesPaused());
        
        // Escalate to full pause - should reset entrance pause and emit events
        vm.expectEmit(true, false, false, false);
        emit EntranceUnpaused(pauser);
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);
        
        iexecLayerZeroBridge.pause();
        vm.stopPrank();

        assertTrue(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.entrancesPaused());
    }

    function test_DualPause_UnpauseFromFullRestoresOperational() public {
        vm.startPrank(pauser);
        
        // Go through: operational -> entrance pause -> full pause -> operational
        iexecLayerZeroBridge.pauseEntrances();
        iexecLayerZeroBridge.pause();
        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Should be fully operational
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.entrancesPaused());
    }

    function test_PauseState_ReturnsCorrectStates() public { // fails
        // Initially operational
        (bool fullyPaused, bool entrancesPaused_, bool fullyOperational) = iexecLayerZeroBridge.pauseState();
        assertFalse(fullyPaused);
        assertFalse(entrancesPaused_);
        assertTrue(fullyOperational);
        
        // After entrance pause
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseEntrances();
        
        (fullyPaused, entrancesPaused_, fullyOperational) = iexecLayerZeroBridge.pauseState();
        assertFalse(fullyPaused);
        assertTrue(entrancesPaused_);
        assertFalse(fullyOperational);
        
        // After full pause
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();
        
        (fullyPaused, entrancesPaused_, fullyOperational) = iexecLayerZeroBridge.pauseState();
        assertTrue(fullyPaused);
        assertFalse(entrancesPaused_); // Reset when fully paused
        assertFalse(fullyOperational);
    }

    // ============ EDGE CASE TESTS ============

    function test_PauseEntrances_CannotUnpauseWhenFullyPaused() public { //fails
        vm.startPrank(pauser);
        
        // Pause entrances then full pause
        iexecLayerZeroBridge.pauseEntrances();
        iexecLayerZeroBridge.pause();
        
        // Attempt to unpause entrances while fully paused - should revert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.unpauseEntrances();
        
        vm.stopPrank();
    }

    function test_PauseEntrances_CannotUnpauseWhenNotPaused() public {
        // Attempt to unpause entrances when not paused
        vm.prank(pauser);
        vm.expectRevert(DualPausableUpgradeable.EntrancesNotPaused.selector);
        iexecLayerZeroBridge.unpauseEntrances();
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
