// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/utils/DualPausableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

/**
 * @title DualPausableUpgradeableTest
 * @dev Test suite for DualPausableUpgradeable abstract contract
 * Tests the dual-pause mechanism with Level 1 (complete) and Level 2 (outbound transfers only) pause functionality
 */
contract DualPausableUpgradeableTest is Test {
    address private OWNER = makeAddr("owner");

    DualPausableUpgradeableImpl private dualPausable;

    function setUp() public {
        dualPausable = new DualPausableUpgradeableImpl();
        vm.prank(OWNER);
        dualPausable.initialize();

        vm.label(address(dualPausable), "dualPausable");
    }

    // ============ initialize ============

    function test_initialize_SetsCorrectInitialStates() public view {
        assertFalse(dualPausable.outbountTransfersPaused(), "Send should not be paused initially");

        (bool fullyPaused, bool onlyOutboundTransfersPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused initially");
        assertFalse(onlyOutboundTransfersPaused, "Send should not be paused initially");
    }

    // ============ pauseOutboundTransfers ============

    function test_pauseOutboundTransfers_EmitsCorrectEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DualPausableUpgradeable.OutboundTransfersPaused(OWNER);
        vm.prank(OWNER);
        dualPausable.pauseOutboundTransfers();
    }

    function test_pauseOutboundTransfers_BlocksOperations() public {
        vm.prank(OWNER);
        dualPausable.pauseOutboundTransfers();

        assertTrue(dualPausable.outbountTransfersPaused(), "Send should be paused after pauseOutboundTransfers");

        vm.expectRevert(DualPausableUpgradeable.EnforcedOutboundTransfersPause.selector);
        dualPausable.mockOperation();
    }

    function test_RevertWhen_OutboundTransferAlreadyPaused() public {
        vm.startPrank(OWNER);
        dualPausable.pauseOutboundTransfers();

        vm.expectRevert(DualPausableUpgradeable.EnforcedOutboundTransfersPause.selector);
        dualPausable.pauseOutboundTransfers();
        vm.stopPrank();
    }

    // ============ unpauseOutboundTransfers ============

    function test_unpauseOutboundTransfers_EmitsCorrectEvent() public {
        vm.startPrank(OWNER);
        dualPausable.pauseOutboundTransfers();

        vm.expectEmit(true, true, true, true);
        emit DualPausableUpgradeable.OutboundTransfersUnpaused(OWNER);
        dualPausable.unpauseOutboundTransfers();
        vm.stopPrank();
    }

    function test_unpauseOutboundTransfers_RestoresOperations() public {
        vm.startPrank(OWNER);
        dualPausable.pauseOutboundTransfers();
        assertTrue(dualPausable.outbountTransfersPaused(), "Send should be paused before unpause");

        dualPausable.unpauseOutboundTransfers();
        vm.stopPrank();

        assertFalse(dualPausable.outbountTransfersPaused(), "Send should not be paused after unpause");

        // Operation should work normally
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed after unpause");
    }

    function test_RevertWhen_OutbountTransfersNotPaused() public {
        vm.expectRevert(DualPausableUpgradeable.ExpectedOutboundTransfersPause.selector);
        dualPausable.unpauseOutboundTransfers();
    }

    // ============ unpause ============

    function test_unpause_RestoresFullOperationality() public {
        vm.startPrank(OWNER);

        // Start with full pause
        dualPausable.pause();
        assertTrue(dualPausable.paused(), "Contract should be paused before unpause");

        // Unpause completely
        dualPausable.unpause();
        vm.stopPrank();

        assertFalse(dualPausable.paused(), "Contract should not be paused after unpause");

        // Operation should work normally
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed after full unpause");
    }

    // ============ pauseStatus ============

    function test_pauseStatus_ReturnsCorrectStatesInAllScenarios() public {
        // Initially operational
        (bool fullyPaused, bool onlyOutboundTransfersPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused initially");
        assertFalse(onlyOutboundTransfersPaused, "Send should not be paused initially");

        // After outbount transfer pause
        vm.prank(OWNER);
        dualPausable.pauseOutboundTransfers();

        (fullyPaused, onlyOutboundTransfersPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused during outbount transfer pause");
        assertTrue(onlyOutboundTransfersPaused, "Send should be paused during outbount transfer pause state");

        // After full pause (from outbount transfer only pause state)
        vm.prank(OWNER);
        dualPausable.pause();

        (fullyPaused, onlyOutboundTransfersPaused) = dualPausable.pauseStatus();
        assertTrue(fullyPaused, "Contract should be fully paused after pause");
        assertTrue(onlyOutboundTransfersPaused, "Send should remain paused during full pause");
    }

    // ============ dual pause workflow tests ============

    // Make sure `pause()` does not impact `pauseOutboundTransfers()`.
    function test_DualPause_PauseFromOnlyOutboundTransfersToFull() public {
        // Start with outbount transfer pause
        vm.startPrank(OWNER);
        dualPausable.pauseOutboundTransfers();
        assertTrue(dualPausable.outbountTransfersPaused());
        assertFalse(dualPausable.paused());

        dualPausable.pause();
        vm.stopPrank();

        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.outbountTransfersPaused());
    }

    // Make sure `pauseOutboundTransfers()` does not impact `pause()`.
    function test_DualPause_PauseFromFullToOnlyOutboundTransfers() public {
        // pause
        vm.startPrank(OWNER);
        dualPausable.pause();
        assertTrue(dualPausable.paused());
        assertFalse(dualPausable.outbountTransfersPaused());
        // pauseOutboundTransfers
        dualPausable.pauseOutboundTransfers();
        vm.stopPrank();
        // Check status
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.outbountTransfersPaused());
    }

    function test_DualPause_PauseShouldNotImpactOutboundTransfersPause() public {
        vm.startPrank(OWNER);
        // pause & pauseOutboundTransfers
        dualPausable.pause();
        dualPausable.pauseOutboundTransfers();
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.outbountTransfersPaused());
        // unpause
        dualPausable.unpause();
        assertFalse(dualPausable.paused());
        // pauseOutboundTransfers should still be active
        assertTrue(dualPausable.outbountTransfersPaused(), "Send should remain paused after unpause");
        vm.stopPrank();
    }

    function test_DualPause_OutboundTransfersPauseShouldNotImpactPause() public {
        vm.startPrank(OWNER);
        // pause & pauseOutboundTransfers
        dualPausable.pause();
        dualPausable.pauseOutboundTransfers();
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.outbountTransfersPaused());
        // unpauseOutboundTransfers
        dualPausable.unpauseOutboundTransfers();
        assertFalse(dualPausable.outbountTransfersPaused());
        // pause should still be active
        assertTrue(dualPausable.paused(), "Pause should remain active after unpauseOutboundTransfers");
        vm.stopPrank();
    }

    // ============ modifier ============

    function test_whenOutboundTransfersNotPaused_AllowsAllTransfersWhenLifted() public view {
        // Should work when fully operational
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed when operational");
    }

    function test_RevertWhen_whenOutboundTransfersNotPaused_OutboundTransfersArePaused() public {
        vm.prank(OWNER);
        dualPausable.pauseOutboundTransfers();

        vm.expectRevert(DualPausableUpgradeable.EnforcedOutboundTransfersPause.selector);
        dualPausable.mockOperation();
    }
}

/**
 * @title DualPausableUpgradeableImpl
 * @dev Concrete implementation of DualPausableUpgradeable for testing
 * Includes a mock functions that use `whenOutboundTransfersNotPaused` modifiers
 */
contract DualPausableUpgradeableImpl is DualPausableUpgradeable {
    function initialize() public initializer {
        __DualPausable_init();
    }

    function pause() external {
        _pause();
    }

    function unpause() external {
        _unpause();
    }

    function pauseOutboundTransfers() external {
        _pauseOutboundTransfers();
    }

    function unpauseOutboundTransfers() external {
        _unpauseOutboundTransfers();
    }

    /**
     * @dev Mock function that uses whenOutboundTransfersNotPaused modifier
     */
    function mockOperation() external view whenOutboundTransfersNotPaused returns (bool) {
        return true;
    }
}
