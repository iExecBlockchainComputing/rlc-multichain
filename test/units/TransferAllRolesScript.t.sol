// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";

contract TransferAllRolesScriptTest is TestHelperOz5 {
    using TestUtils for *;

    IexecLayerZeroBridge public iexecLayerZeroBridge;
    RLCCrosschainToken public rlcCrosschainToken;

    address public mockEndpoint;
    address public oldAdmin = makeAddr("oldAdmin"); // Compromised address with ALL roles
    address public newAdmin = makeAddr("newAdmin"); // New secure address

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);
        mockEndpoint = address(endpoints[1]);

        // Deploy contracts with the old admin having ALL roles (matching real scenario)
        TestUtils.DeploymentResult memory deploymentResult = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridge",
                lzEndpointSource: mockEndpoint,
                lzEndpointDestination: mockEndpoint,
                initialAdmin: oldAdmin,
                initialUpgrader: oldAdmin, // Same as admin (compromised has all roles)
                initialPauser: oldAdmin // Same as admin (compromised has all roles)
            })
        );

        iexecLayerZeroBridge = deploymentResult.iexecLayerZeroBridgeWithoutApproval;
        rlcCrosschainToken = deploymentResult.rlcCrosschainToken;

        // Grant all additional roles to oldAdmin (simulating real scenario where admin granted themselves all roles)
        vm.startPrank(oldAdmin);
        // Token roles
        rlcCrosschainToken.grantRole(PAUSER_ROLE, oldAdmin);
        rlcCrosschainToken.grantRole(TOKEN_BRIDGE_ROLE, address(iexecLayerZeroBridge));
        
        // Bridge roles  
        iexecLayerZeroBridge.grantRole(PAUSER_ROLE, oldAdmin);
        vm.stopPrank();
    }

    function test_GrantRolesAndBeginTransfer() public {
        // Verify initial state - old admin has all roles
        _verifyOldAdminHasAllRoles();
        _verifyNewAdminHasNoRoles();

        // Step 1: Grant roles and begin admin transfer (as old admin)
        vm.startPrank(oldAdmin);

        // Grant roles on RLCCrosschainToken
        rlcCrosschainToken.grantRole(UPGRADER_ROLE, newAdmin);
        rlcCrosschainToken.grantRole(PAUSER_ROLE, newAdmin);
        rlcCrosschainToken.grantRole(TOKEN_BRIDGE_ROLE, newAdmin);
        rlcCrosschainToken.beginDefaultAdminTransfer(newAdmin);

        // Grant roles on IexecLayerZeroBridge
        iexecLayerZeroBridge.grantRole(UPGRADER_ROLE, newAdmin);
        iexecLayerZeroBridge.grantRole(PAUSER_ROLE, newAdmin);
        iexecLayerZeroBridge.beginDefaultAdminTransfer(newAdmin);

        vm.stopPrank();

        // Verify new admin has non-admin roles but not DEFAULT_ADMIN yet
        assertTrue(rlcCrosschainToken.hasRole(UPGRADER_ROLE, newAdmin), "New admin should have UPGRADER_ROLE on token");
        assertTrue(rlcCrosschainToken.hasRole(PAUSER_ROLE, newAdmin), "New admin should have PAUSER_ROLE on token");
        assertTrue(
            rlcCrosschainToken.hasRole(TOKEN_BRIDGE_ROLE, newAdmin), "New admin should have TOKEN_BRIDGE_ROLE on token"
        );
        assertFalse(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should not have DEFAULT_ADMIN_ROLE yet"
        );

        assertTrue(
            iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAdmin), "New admin should have UPGRADER_ROLE on bridge"
        );
        assertTrue(iexecLayerZeroBridge.hasRole(PAUSER_ROLE, newAdmin), "New admin should have PAUSER_ROLE on bridge");
        assertFalse(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should not have DEFAULT_ADMIN_ROLE yet"
        );

        // Verify pending admin transfer
        (address pendingAdminToken,) = rlcCrosschainToken.pendingDefaultAdmin();
        (address pendingAdminBridge,) = iexecLayerZeroBridge.pendingDefaultAdmin();
        assertEq(pendingAdminToken, newAdmin, "Pending admin should be new admin on token");
        assertEq(pendingAdminBridge, newAdmin, "Pending admin should be new admin on bridge");
    }

    function test_AcceptAdminAndRevokeOldRoles() public {
        // First, complete step 1
        test_GrantRolesAndBeginTransfer();

        // Fast forward past the delay period
        (, uint48 scheduleToken) = rlcCrosschainToken.pendingDefaultAdmin();
        vm.warp(scheduleToken + 1);

        // Step 2: Accept admin and revoke old roles (as new admin)
        vm.startPrank(newAdmin);

        // Accept admin role on RLCCrosschainToken
        rlcCrosschainToken.acceptDefaultAdminTransfer();

        // Accept admin role on IexecLayerZeroBridge
        iexecLayerZeroBridge.acceptDefaultAdminTransfer();

        // Revoke all roles from old admin on RLCCrosschainToken
        rlcCrosschainToken.revokeRole(UPGRADER_ROLE, oldAdmin);
        rlcCrosschainToken.revokeRole(PAUSER_ROLE, oldAdmin);
        rlcCrosschainToken.revokeRole(TOKEN_BRIDGE_ROLE, oldAdmin);

        // Revoke all roles from old admin on IexecLayerZeroBridge
        iexecLayerZeroBridge.revokeRole(UPGRADER_ROLE, oldAdmin);
        iexecLayerZeroBridge.revokeRole(PAUSER_ROLE, oldAdmin);

        vm.stopPrank();

        // Verify new admin has all roles
        assertTrue(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should have DEFAULT_ADMIN_ROLE on token"
        );
        assertTrue(rlcCrosschainToken.hasRole(UPGRADER_ROLE, newAdmin), "New admin should have UPGRADER_ROLE on token");
        assertTrue(rlcCrosschainToken.hasRole(PAUSER_ROLE, newAdmin), "New admin should have PAUSER_ROLE on token");
        assertTrue(
            rlcCrosschainToken.hasRole(TOKEN_BRIDGE_ROLE, newAdmin), "New admin should have TOKEN_BRIDGE_ROLE on token"
        );

        assertTrue(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should have DEFAULT_ADMIN_ROLE on bridge"
        );
        assertTrue(
            iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAdmin), "New admin should have UPGRADER_ROLE on bridge"
        );
        assertTrue(iexecLayerZeroBridge.hasRole(PAUSER_ROLE, newAdmin), "New admin should have PAUSER_ROLE on bridge");

        // Verify old admin has no roles
        _verifyOldAdminHasNoRoles();
    }

    function test_CannotAcceptBeforeDelay() public {
        // First, complete step 1
        test_GrantRolesAndBeginTransfer();

        // Try to accept before delay (should revert)
        vm.prank(newAdmin);
        vm.expectRevert();
        rlcCrosschainToken.acceptDefaultAdminTransfer();

        vm.prank(newAdmin);
        vm.expectRevert();
        iexecLayerZeroBridge.acceptDefaultAdminTransfer();
    }

    function test_OldAdminStillHasAccessDuringDelay() public {
        // First, complete step 1
        test_GrantRolesAndBeginTransfer();

        // Verify old admin still has DEFAULT_ADMIN_ROLE during delay
        assertTrue(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should still have DEFAULT_ADMIN_ROLE during delay"
        );
        assertTrue(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should still have DEFAULT_ADMIN_ROLE during delay"
        );
    }

    function _verifyOldAdminHasAllRoles() internal view {
        // RLCCrosschainToken
        assertTrue(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should have DEFAULT_ADMIN_ROLE on token"
        );
        assertTrue(rlcCrosschainToken.hasRole(UPGRADER_ROLE, oldAdmin), "Old admin should have UPGRADER_ROLE on token");
        assertTrue(rlcCrosschainToken.hasRole(PAUSER_ROLE, oldAdmin), "Old admin should have PAUSER_ROLE on token");

        // IexecLayerZeroBridge
        assertTrue(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should have DEFAULT_ADMIN_ROLE on bridge"
        );
        assertTrue(
            iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, oldAdmin), "Old admin should have UPGRADER_ROLE on bridge"
        );
        assertTrue(iexecLayerZeroBridge.hasRole(PAUSER_ROLE, oldAdmin), "Old admin should have PAUSER_ROLE on bridge");
    }

    function _verifyNewAdminHasNoRoles() internal view {
        // RLCCrosschainToken
        assertFalse(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should not have DEFAULT_ADMIN_ROLE on token"
        );
        assertFalse(
            rlcCrosschainToken.hasRole(UPGRADER_ROLE, newAdmin), "New admin should not have UPGRADER_ROLE on token"
        );
        assertFalse(rlcCrosschainToken.hasRole(PAUSER_ROLE, newAdmin), "New admin should not have PAUSER_ROLE on token");
        assertFalse(
            rlcCrosschainToken.hasRole(TOKEN_BRIDGE_ROLE, newAdmin),
            "New admin should not have TOKEN_BRIDGE_ROLE on token"
        );

        // IexecLayerZeroBridge
        assertFalse(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), newAdmin),
            "New admin should not have DEFAULT_ADMIN_ROLE on bridge"
        );
        assertFalse(
            iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAdmin), "New admin should not have UPGRADER_ROLE on bridge"
        );
        assertFalse(
            iexecLayerZeroBridge.hasRole(PAUSER_ROLE, newAdmin), "New admin should not have PAUSER_ROLE on bridge"
        );
    }

    function _verifyOldAdminHasNoRoles() internal view {
        // RLCCrosschainToken
        assertFalse(
            rlcCrosschainToken.hasRole(rlcCrosschainToken.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should not have DEFAULT_ADMIN_ROLE on token"
        );
        assertFalse(
            rlcCrosschainToken.hasRole(UPGRADER_ROLE, oldAdmin), "Old admin should not have UPGRADER_ROLE on token"
        );
        assertFalse(rlcCrosschainToken.hasRole(PAUSER_ROLE, oldAdmin), "Old admin should not have PAUSER_ROLE on token");
        assertFalse(
            rlcCrosschainToken.hasRole(TOKEN_BRIDGE_ROLE, oldAdmin),
            "Old admin should not have TOKEN_BRIDGE_ROLE on token"
        );

        // IexecLayerZeroBridge
        assertFalse(
            iexecLayerZeroBridge.hasRole(iexecLayerZeroBridge.DEFAULT_ADMIN_ROLE(), oldAdmin),
            "Old admin should not have DEFAULT_ADMIN_ROLE on bridge"
        );
        assertFalse(
            iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, oldAdmin), "Old admin should not have UPGRADER_ROLE on bridge"
        );
        assertFalse(
            iexecLayerZeroBridge.hasRole(PAUSER_ROLE, oldAdmin), "Old admin should not have PAUSER_ROLE on bridge"
        );
    }
}
