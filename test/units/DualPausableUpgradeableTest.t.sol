// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {DualPausableUpgradeable} from "../../src/utils/DualPausableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

/**
 * @title DualPausableUpgradeableTest
 * @dev Test suite for DualPausableUpgradeable abstract contract
 * Tests the dual-pause mechanism with Level 1 (complete) and Level 2 (send-only) pause functionality
 */
contract DualPausableUpgradeableTest is Test {
    // ============ TEST IMPLEMENTATION CONTRACT ============

    /**
     * @dev Concrete implementation of DualPausableUpgradeable for testing
     * Includes mock functions that use the pause modifiers
     */
    DualPausableTestImpl private dualPausable;

    // ============ TEST ACCOUNTS ============
    address private OWNER = makeAddr("owner");

    // ============ EVENTS ============
    event SendPaused(address account);
    event SendUnpaused(address account);

    function setUp() public {
        dualPausable = new DualPausableTestImpl();
        vm.prank(OWNER);
        dualPausable.initialize();
    }

    // ============ INITIALIZE TESTS ============

    function test_initialize_SetsCorrectInitialStates() public view {
        assertFalse(dualPausable.sendPaused(), "Send should not be paused initially");

        (bool fullyPaused, bool onlySendPaused) = dualPausable.pauseStatus();
        assertFalse(fullyPaused, "Contract should not be fully paused initially");
        assertFalse(onlySendPaused, "Send should not be paused initially");
    }

    // ============ PAUSESEND TESTS ============

    function test_pauseSend_EmitsCorrectEvent() public {
        vm.expectEmit(true, true, true, true);
        emit SendPaused(OWNER);

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

    function test_RevertWhen_pauseSend_AlreadyPaused() public {
        vm.startPrank(OWNER);
        dualPausable.pauseSend();

        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        dualPausable.pauseSend();
        vm.stopPrank();
    }

    // ============ UNPAUSESEND TESTS ============

    function test_unpauseSend_EmitsCorrectEvent() public {
        vm.startPrank(OWNER);
        dualPausable.pauseSend();

        vm.expectEmit(true, true, true, true);
        emit SendUnpaused(OWNER);
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

    function test_RevertWhen_unpauseSend_NotPaused() public {
        vm.expectRevert(DualPausableUpgradeable.ExpectedSendPause.selector);
        dualPausable.unpauseSend();
    }

    // ============ UNPAUSE TESTS ============

    function test_unpause_RestoresFullOperationality() public {
        vm.startPrank(OWNER);

        // Start with full pause
        dualPausable.pause();
        assertTrue(dualPausable.paused(), "Contract should be paused before unpause");

        // Unpause completely
        dualPausable.unpause();
        vm.stopPrank();

        assertFalse(dualPausable.paused(), "Contract should not be paused after unpause");
        assertFalse(dualPausable.sendPaused(), "Send should not be paused after unpause");

        // Operation should work normally
        assertTrue(dualPausable.mockOperation(), "Mock operation should succeed after full unpause");
    }

    // ============ PAUSESTATUS TESTS ============

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

    // ============ DUAL PAUSE WORKFLOW TESTS ============

    function test_DualPause_PauseFromSendToFull() public {
        // Start with send pause
        vm.startPrank(OWNER);
        dualPausable.pauseSend();
        assertTrue(dualPausable.sendPaused());


        dualPausable.pause();
        vm.stopPrank();

        assertTrue(dualPausable.paused());
        assertTrue(dualPausable.sendPaused());
    }

    // ============ MODIFIER TESTS ============

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
 * @title DualPausableTestImpl
 * @dev Concrete implementation of DualPausableUpgradeable for testing
 */
contract DualPausableTestImpl is DualPausableUpgradeable {
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
