// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {PauseBridge, UnpauseBridge, PauseOutboundTransfers, UnpauseOutboundTransfers, PauseBridgeValidation} from
    "../../script/PauseBridge.s.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {ConfigLib} from "./../../script/lib/ConfigLib.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {DualPausableUpgradeable} from "../../src/bridges/utils/DualPausableUpgradeable.sol";

contract PauseBridgeScriptTest is
    TestHelperOz5,
    PauseBridge,
    UnpauseBridge,
    PauseOutboundTransfers,
    UnpauseOutboundTransfers
{
    using TestUtils for *;

    // Test addresses
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    address private pauser = makeAddr("pauser");
    address private unauthorizedUser = makeAddr("unauthorizedUser");
    uint16 private sourceEndpointId = 1;
    uint16 private targetEndpointId = 2;
    IexecLayerZeroBridge iexecLayerZeroBridge;
    ConfigLib.CommonConfigParams params;
    TestUtils.DeploymentResult deployment;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        deployment = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: endpoints[sourceEndpointId],
                lzEndpointDestination: endpoints[targetEndpointId],
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );
        iexecLayerZeroBridge = deployment.iexecLayerZeroBridgeWithApproval;
        buildParams();
    }

    // Override run functions to resolve inheritance conflict
    function run()
        external
        pure
        override(PauseBridge, UnpauseBridge, PauseOutboundTransfers, UnpauseOutboundTransfers)
    {
        // This function should not be called directly in tests
        // Use specific test functions instead
        revert("Use specific test functions instead");
    }

    // ====== Test Library Validation Functions ======
    function test_ValidateBridgeAddress() public pure {
        // Should not revert with valid address
        PauseBridgeValidation.validateBridgeAddress(address(0x123));
    }
    
    function test_ValidatesBridgeAddress_RevertWhen_BridgeIsZeroAddress() public {
        vm.expectRevert("Bridge address cannot be zero");
        this.callValidateBridgeAddress(address(0));
    }

    // ====== PauseBridge.pauseBridge ======

    function test_PauseBridge() public {
        // Check initial state
        assertFalse(iexecLayerZeroBridge.paused());
        vm.startPrank(pauser);
        super.pauseBridge(params);
        vm.stopPrank();
        // Verify paused
        assertTrue(iexecLayerZeroBridge.paused());
    }

    function test_PauseBridge_RevertWhen_UnauthorizedUser() public {
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.pauseBridge(params);
        vm.stopPrank();
    }

    function test_PauseBridge_Run() public {
        // Check initial state
        assertFalse(iexecLayerZeroBridge.paused());
        
        vm.startPrank(pauser);
        super.pauseBridge(params);
        vm.stopPrank();
        
        // Verify bridge is paused
        assertTrue(iexecLayerZeroBridge.paused());
        // Verify outbound transfers are also effectively blocked (due to complete pause)
        assertTrue(iexecLayerZeroBridge.paused());
    }

    // ====== UnpauseBridge.unpauseBridge ======

    function test_UnpauseBridge() public {
        test_PauseBridge();
        vm.startPrank(pauser);
        super.unpauseBridge(params);
        vm.stopPrank();
        // Verify unpaused
        assertFalse(iexecLayerZeroBridge.paused());
    }

    function test_UnpauseBridge_RevertWhen_UnauthorizedUser() public {
        // First pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();
        assertTrue(iexecLayerZeroBridge.paused());

        // Try to unpause with unauthorized user
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.unpauseBridge(params);
        vm.stopPrank();
    }

    function test_UnpauseBridge_Run() public {
        // First pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();
        assertTrue(iexecLayerZeroBridge.paused());

        // Now unpause using the script
        vm.startPrank(pauser);
        super.unpauseBridge(params);
        vm.stopPrank();
        
        // Verify bridge is unpaused
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
    }

    // ====== PauseOutboundTransfers.pauseOutboundTransfers ======

    function test_PauseOutboundTransfers() public {
        // Check initial state
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        vm.startPrank(pauser);
        super.pauseOutboundTransfers(params);
        vm.stopPrank();
        // Verify paused
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
    }

    function test_PauseOutboundTransfers_RevertWhen_UnauthorizedUser() public {
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.pauseOutboundTransfers(params);
        vm.stopPrank();
    }

    function test_PauseOutboundTransfers_Run() public {
        // Check initial state
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        assertFalse(iexecLayerZeroBridge.paused());
        
        vm.startPrank(pauser);
        super.pauseOutboundTransfers(params);
        vm.stopPrank();
        
        // Verify only outbound transfers are paused, but not the full bridge
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        assertFalse(iexecLayerZeroBridge.paused());
    }

    // ====== UnpauseOutboundTransfers.unpauseOutboundTransfers ======

    function test_UnpauseOutboundTransfers() public {
        test_PauseOutboundTransfers();
        vm.startPrank(pauser);
        super.unpauseOutboundTransfers(params);
        vm.stopPrank();
        // Verify unpaused
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
    }

    function test_UnpauseOutboundTransfers_RevertWhen_UnauthorizedUser() public {
        // First pause outbound transfers
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseOutboundTransfers();
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());

        // Try to unpause with unauthorized user
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.unpauseOutboundTransfers(params);
        vm.stopPrank();
    }

    function test_UnpauseOutboundTransfers_Run() public {
        // First pause outbound transfers
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseOutboundTransfers();
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());

        // Now unpause using the script
        vm.startPrank(pauser);
        super.unpauseOutboundTransfers(params);
        vm.stopPrank();
        
        // Verify outbound transfers are unpaused
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        assertFalse(iexecLayerZeroBridge.paused());
    }

    // ====== Comprehensive State Tests ======

    function test_PauseUnpauseSequence_CompletePause() public {
        // Initial state
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Pause completely
        vm.prank(pauser);
        super.pauseBridge(params);
        assertTrue(iexecLayerZeroBridge.paused());
        
        // Unpause
        vm.prank(pauser);
        super.unpauseBridge(params);
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
    }

    function test_PauseUnpauseSequence_OutboundTransfersOnly() public {
        // Initial state
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Pause outbound transfers only
        vm.prank(pauser);
        super.pauseOutboundTransfers(params);
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Unpause outbound transfers
        vm.prank(pauser);
        super.unpauseOutboundTransfers(params);
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
    }

    function test_MixedPauseScenarios() public {
        // Start with outbound pause
        vm.startPrank(pauser);
        super.pauseOutboundTransfers(params);
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Then escalate to complete pause
        super.pauseBridge(params);
        assertTrue(iexecLayerZeroBridge.paused());
        // Note: When completely paused, outbound state is still true
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Unpause completely
        super.unpauseBridge(params);
        assertFalse(iexecLayerZeroBridge.paused());
        // After unpause, outbound transfers should still be paused from before
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Now unpause outbound transfers
        super.unpauseOutboundTransfers(params);
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        vm.stopPrank();
    }

    // ====== Role and Authorization Tests ======

    function test_PauserRoleRequired_ForAllPauseFunctions() public {
        // Verify pauser has the required role
        assertTrue(iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.PAUSER_ROLE(), pauser));
        
        // Verify unauthorized user does not have the role
        assertFalse(iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.PAUSER_ROLE(), unauthorizedUser));
        
        // Test all pause functions require PAUSER_ROLE
        vm.startPrank(unauthorizedUser);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.pauseBridge(params);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.unpauseBridge(params);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.pauseOutboundTransfers(params);
        
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), iexecLayerZeroBridge.PAUSER_ROLE())
        );
        this.unpauseOutboundTransfers(params);
        
        vm.stopPrank();
    }

    // ====== Edge Cases and Error Conditions ======

    function test_ValidateBridgeAddress_RevertWhen_ZeroAddress() public {
        ConfigLib.CommonConfigParams memory invalidParams;
        invalidParams.iexecLayerZeroBridgeAddress = address(0);
        
        vm.startPrank(pauser);
        vm.expectRevert("Bridge address cannot be zero");
        this.pauseBridge(invalidParams);
        vm.stopPrank();
    }

    function test_PauseWhenAlreadyPaused_ShouldRevert() public {
        // Pause the bridge
        vm.startPrank(pauser);
        super.pauseBridge(params);
        assertTrue(iexecLayerZeroBridge.paused());
        
        // Try to pause again - should revert with EnforcedPause
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        super.pauseBridge(params);
        vm.stopPrank();
    }

    function test_UnpauseWhenAlreadyUnpaused_ShouldRevert() public {
        // Ensure bridge is unpaused
        assertFalse(iexecLayerZeroBridge.paused());
        
        // Try to unpause when already unpaused - should revert with ExpectedPause
        vm.startPrank(pauser);
        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector);
        super.unpauseBridge(params);
        vm.stopPrank();
    }

    function test_PauseOutboundTransfersWhenAlreadyPaused_ShouldRevert() public {
        // Pause outbound transfers
        vm.startPrank(pauser);
        super.pauseOutboundTransfers(params);
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Try to pause again - should revert with EnforcedOutboundTransfersPause
        vm.expectRevert(DualPausableUpgradeable.EnforcedOutboundTransfersPause.selector);
        super.pauseOutboundTransfers(params);
        vm.stopPrank();
    }

    function test_UnpauseOutboundTransfersWhenAlreadyUnpaused_ShouldRevert() public {
        // Ensure outbound transfers are unpaused
        assertFalse(iexecLayerZeroBridge.outboundTransfersPaused());
        
        // Try to unpause when already unpaused - should revert with ExpectedOutboundTransfersPause
        vm.startPrank(pauser);
        vm.expectRevert(DualPausableUpgradeable.ExpectedOutboundTransfersPause.selector);
        super.unpauseOutboundTransfers(params);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Helper function to configure params for testing
     */
    function buildParams() internal {
        params.iexecLayerZeroBridgeAddress = address(iexecLayerZeroBridge);
    }

    // Helper functions to enable testing of library functions with vm.expectRevert
    function callValidateBridgeAddress(address bridgeAddress) external pure {
        PauseBridgeValidation.validateBridgeAddress(bridgeAddress);
    }

    // Helper functions to enable testing of script functions with vm.expectRevert
    function pauseBridge(ConfigLib.CommonConfigParams memory _params) public override {
        super.pauseBridge(_params);
    }

    function unpauseBridge(ConfigLib.CommonConfigParams memory _params) public override {
        super.unpauseBridge(_params);
    }

    function pauseOutboundTransfers(ConfigLib.CommonConfigParams memory _params) public override {
        super.pauseOutboundTransfers(_params);
    }

    function unpauseOutboundTransfers(ConfigLib.CommonConfigParams memory _params) public override {
        super.unpauseOutboundTransfers(_params);
    }
}