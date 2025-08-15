// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {
    PauseBridge,
    UnpauseBridge,
    PauseOutboundTransfers,
    UnpauseOutboundTransfers,
    PauseBridgeValidation
} from "../../script/PauseBridge.s.sol";
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
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.pauseBridge(params);
        vm.stopPrank();
    }

    // ====== UnpauseBridge.unpauseBridge ======

    function test_UnpauseBridge() public {
        // First pause the bridge
        test_PauseBridge();

        vm.startPrank(pauser);
        super.unpauseBridge(params);
        vm.stopPrank();
        assertFalse(iexecLayerZeroBridge.paused());
    }

    function test_UnpauseBridge_RevertWhen_UnauthorizedUser() public {
        // First pause the bridge
        test_PauseBridge();

        // Try to unpause with unauthorized user
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.unpauseBridge(params);
        vm.stopPrank();
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
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.pauseOutboundTransfers(params);
        vm.stopPrank();
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
        test_PauseOutboundTransfers();
        assertTrue(iexecLayerZeroBridge.outboundTransfersPaused());

        // Try to unpause with unauthorized user
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.unpauseOutboundTransfers(params);
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
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.pauseBridge(params);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.unpauseBridge(params);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
        );
        this.pauseOutboundTransfers(params);

        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(this),
                iexecLayerZeroBridge.PAUSER_ROLE()
            )
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
}
