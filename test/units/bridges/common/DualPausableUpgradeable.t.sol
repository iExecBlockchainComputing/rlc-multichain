// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/common/DualPausableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

/**
 * @title DualPausableUpgradeableTest
 * @dev Test suite for DualPausableUpgradeable abstract contract
 * Tests the dual-pause mechanism with Level 1 (complete) and Level 2 (send-only) pause functionality
 */
contract DualPausableUpgradeableTest is Test {
    address private OWNER = makeAddr("owner");

    DualPausableUpgradeableImpl private dualPausable;

    function setUp() public {
        dualPausable = new DualPausableUpgradeableImpl();
        vm.prank(OWNER);
        dualPausable.initialize();
    }

    // ============ initialize ============

    function test_initialize_SetsCorrectInitialStates() public view {
        assertFalse(dualPausable.sendPaused(), "Send should not be paused initially");

        (bool fullyPaused, bool onlySendPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused initially");
        assertFalse(onlySendPaused, "Send should not be paused initially");
    }

    // ============ pauseSend ============

    function test_pauseSend_EmitsCorrectEvent() public {
        vm.expectEmit(true, true, true, true);
        emit DualPausableUpgradeable.SendPaused(OWNER);
        vm.prank(OWNER);
        dualPausable.pauseSend();
    }

    function test_pauseSend_BlocksOperations() public {
        vm.prank(OWNER);
        dualPausable.pauseSend();

        assertTrue(dualPausable.sendPaused(), "Send should be paused after pauseSend");

        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        dualPausable.mockOperation();
    }

    function test_RevertWhen_SendAlreadyPaused() public {
        vm.startPrank(OWNER);
        dualPausable.pauseSend();

        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        dualPausable.pauseSend();
        vm.stopPrank();
    }

    // ============ unpauseSend ============

    function test_unpauseSend_EmitsCorrectEvent() public {
        vm.startPrank(OWNER);
        dualPausable.pauseSend();

        vm.expectEmit(true, true, true, true);
        emit DualPausableUpgradeable.SendUnpaused(OWNER);
        dualPausable.unpauseSend();
        vm.stopPrank();
    }

    function test_unpauseSend_RestoresOperations() public {
        vm.startPrank(OWNER);
        dualPausable.pauseSend();
        assertTrue(dualPausable.sendPaused(), "Send should be paused before unpause");

        dualPausable.unpauseSend();
        vm.stopPrank();

        assertFalse(dualPausable.sendPaused(), "Send should not be paused after unpause");

        // Operation should work normally
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed after unpause");
    }

    function test_RevertWhen_SendNotPaused() public {
        vm.expectRevert(DualPausableUpgradeable.ExpectedSendPause.selector);
        dualPausable.unpauseSend();
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
        (bool fullyPaused, bool onlySendPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused initially");
        assertFalse(onlySendPaused, "Send should not be paused initially");

        // After send pause
        vm.prank(OWNER);
        dualPausable.pauseSend();

        (fullyPaused, onlySendPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused during send pause");
        assertTrue(onlySendPaused, "Send should be paused during send pause state");

        // After full pause (from send pause state)
        vm.prank(OWNER);
        dualPausable.pause();

        (fullyPaused, onlySendPaused) = dualPausable.pauseStatus();
        assertTrue(fullyPaused, "Contract should be fully paused after pause");
        assertTrue(onlySendPaused, "Send should remain paused during full pause");
    }

    // ============ dual pause workflow tests ============

    // Make sure `pause()` does not impact `pauseSend()`.
    function test_DualPause_PauseFromSendToFull() public {
        // Start with send pause
        vm.startPrank(OWNER);
        dualPausable.pauseSend();
        assertTrue(dualPausable.sendPaused());
        assertFalse(dualPausable.paused());

        dualPausable.pause();
        vm.stopPrank();

        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.sendPaused());
    }

    // Make sure `pauseSend()` does not impact `pause()`.
    function test_DualPause_PauseFromFullToSend() public {
        // pause
        vm.startPrank(OWNER);
        dualPausable.pause();
        assertTrue(dualPausable.paused());
        assertFalse(dualPausable.sendPaused());
        // pauseSend
        dualPausable.pauseSend();
        vm.stopPrank();
        // Check status
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.sendPaused());
    }

    function test_DualPause_PauseShouldNotImpactSendPause() public {
        vm.startPrank(OWNER);
        // pause & pauseSend
        dualPausable.pause();
        dualPausable.pauseSend();
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.sendPaused());
        // unpause
        dualPausable.unpause();
        assertFalse(dualPausable.paused());
        // pauseSend should still be active
        assertTrue(dualPausable.sendPaused(), "Send should remain paused after unpause");
        vm.stopPrank();
    }

    function test_DualPause_SendPauseShouldNotImpactPause() public {
        vm.startPrank(OWNER);
        // pause & pauseSend
        dualPausable.pause();
        dualPausable.pauseSend();
        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.sendPaused());
        // unpauseSend
        dualPausable.unpauseSend();
        assertFalse(dualPausable.sendPaused());
        // pause should still be active
        assertTrue(dualPausable.paused(), "Pause should remain active after unpauseSend");
        vm.stopPrank();
    }

    // ============ modifier ============

    function test_whenSendNotPaused_AllowsOperationWhenOperational() public view {
        // Should work when fully operational
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed when operational");
    }

    function test_RevertWhen_whenSendNotPaused_SendIsPaused() public {
        vm.prank(OWNER);
        dualPausable.pauseSend();

        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        dualPausable.mockOperation();
    }
}

/**
 * @title DualPausableUpgradeableImpl
 * @dev Concrete implementation of DualPausableUpgradeable for testing
 * Includes a mock functions that use `whenSendNotPaused` modifiers
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

    function pauseSend() external {
        _pauseSend();
    }

    function unpauseSend() external {
        _unpauseSend();
    }

    /**
     * @dev Mock function that uses whenNotSendPaused modifier
     */
    function mockOperation() external view whenSendNotPaused returns (bool) {
        return true;
    }
}
