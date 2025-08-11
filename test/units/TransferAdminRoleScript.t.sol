// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {BeginTransferAdminRole, AcceptAdminRole} from "../../script/TransferAdminRole.s.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import "forge-std/console.sol";

import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";

// Test wrapper contract to expose internal functions

contract BeginTransferAdminRoleHarness is BeginTransferAdminRole {

    function run_beginTransfer(address rlcLiquidityUnifier, address rlcCrosschainToken, address iexecLayerZeroBridge, address newAdmin, bool approvalRequired) public {
        // Replicate the logic from BeginTransferAdminRole.run() for testing without env dependencies
        if (approvalRequired) {
            beginTransfer(rlcLiquidityUnifier, newAdmin, "RLCLiquidityUnifier");
        } else {
            beginTransfer(rlcCrosschainToken, newAdmin, "RLCCrosschainToken");
        }
        beginTransfer(iexecLayerZeroBridge, newAdmin, "IexecLayerZeroBridge");

    }
    
    function exposed_beginTransfer(address contractAddress, address newAdmin, string memory contractName) public {
        beginTransfer(contractAddress, newAdmin, contractName);
    }

    function exposed_validateAdminTransfer(address currentDefaultAdmin, address newAdmin) public pure {
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
    }
}

// Test wrapper contract to expose internal functions
contract AcceptAdminRoleHarness is AcceptAdminRole {

    function run_acceptAdmin(address rlcLiquidityUnifier, address rlcCrosschainToken, address iexecLayerZeroBridge, bool approvalRequired) public {
        console.log("msg.sender:", msg.sender);
        // Replicate the logic from AcceptAdminRole.run() for testing without env dependencies
        if (approvalRequired) {
            acceptContractAdmin(rlcLiquidityUnifier, "RLCLiquidityUnifier");
        } else {
            acceptContractAdmin(rlcCrosschainToken, "RLCCrosschainToken");
        }
        acceptContractAdmin(iexecLayerZeroBridge, "IexecLayerZeroBridge");
    }
    
    function exposed_acceptContractAdmin(address contractAddress, string memory contractName) public {
        acceptContractAdmin(contractAddress, contractName);
    }
}

contract TransferAdminRoleScriptTest is TestHelperOz5, BeginTransferAdminRoleHarness, AcceptAdminRoleHarness {
    using TestUtils for *;

    // Test addresses
    address private newAdmin = makeAddr("newAdmin");
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    address private pauser = makeAddr("pauser");
    uint16 private sourceEndpointId = 1;
    uint16 private targetEndpointId = 2;
    RLCLiquidityUnifier rlcLiquidityUnifier;
    RLCCrosschainToken rlcCrosschainToken;
    IexecLayerZeroBridge iexecLayerZeroBridgeL1;
    IexecLayerZeroBridge iexecLayerZeroBridgeL2;

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
        rlcLiquidityUnifier = deployment.rlcLiquidityUnifier;
        rlcCrosschainToken = deployment.rlcCrosschainToken;
        iexecLayerZeroBridgeL1 = deployment.iexecLayerZeroBridgeWithApproval;
        iexecLayerZeroBridgeL2 = deployment.iexecLayerZeroBridgeWithoutApproval;

    }

    // Override run functions to resolve inheritance conflict
    function run() external pure override(BeginTransferAdminRole, AcceptAdminRole) {
        // This function should not be called directly in tests
        // Use this.run_beginTransfer() or super.run_acceptAdmin() instead
        revert("Use specific test functions instead");
    }

    // ====== BeginTransferAdminRole.validateAdminTransfer ======
    function test_ValidateAdminTransfer() public view {
        this.exposed_validateAdminTransfer(admin, newAdmin);
    }

    function test_ValidateAdminTransfer_RevertWhen_NewAdminIsZeroAddress() public {
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        this.exposed_validateAdminTransfer(admin, address(0));
    }

    function test_ValidateAdminTransfer_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        this.exposed_validateAdminTransfer(admin, admin);
    }

    // ====== BeginTransferAdminRole.beginTransfer ======
    function test_BeginTransfer_LiquidityUnifier() public {
        vm.startPrank(admin);
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // Current admin should still be the initial admin until acceptance
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        vm.stopPrank();
    }

    function test_BeginTransferAdminRole_Run_ApprovalRequired() public {
        vm.startPrank(admin);
        super.run_beginTransfer(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL1), newAdmin, true);
        vm.stopPrank();

        // Verify that the admin transfer has been initiated for approval required (RLCLiquidityUnifier)
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // RLCCrosschainToken should not have pending admin since approvalRequired = true
        (pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));

        (pendingAdmin,) = IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL1)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);


    }

    function test_BeginTransferAdminRole_Run_AllContracts_NoApprovalRequired() public {
        vm.startPrank(admin);
        super.run_beginTransfer(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL2), newAdmin, false);
        vm.stopPrank();

        // Verify that the admin transfer has been initiated for no approval required (RLCCrosschainToken)
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // RLCLiquidityUnifier should not have pending admin since approvalRequired = false
        (pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));

        (pendingAdmin,) = IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL2)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);
    }

    // ====== revert scenarios checks ======
    function test_BeginTransfer_RevertWhen_NewAdminIsZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        this.exposed_beginTransfer(address(rlcLiquidityUnifier), address(0), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_BeginTransfer_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        this.exposed_beginTransfer(address(rlcLiquidityUnifier), admin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_BeginTransfer_RevertWhen_NotAuthorizedToTransferAdmin() public {
        address unauthorizedUser = makeAddr("unauthorizedUser");
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), bytes32(0))
        );
        this.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    // ====== AcceptAdminRole.acceptContractAdmin ======
    function test_AcceptAdminRole_LiquidityUnifier() public {
        vm.startPrank(admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();

        // Get the delay schedule and wait for it to pass
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1);

        vm.prank(newAdmin);
        super.exposed_acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);

        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
    }

    function test_AcceptAdminRole_Run_ApprovalRequired() public {
        // Begin transfer first
        vm.startPrank(admin);
        super.run_beginTransfer(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL1), newAdmin, true);
        vm.stopPrank();

        // Get the delay schedule and wait for it to pass
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1);

        // Accept admin role with approval required = true
        vm.startPrank(newAdmin);
        super.run_acceptAdmin(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL1), true);
        vm.stopPrank();

        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);
        assertEq(IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL1)).defaultAdmin(), newAdmin);
        
        // Verify that RLCCrosschainToken admin was not affected
        assertEq(IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).defaultAdmin(), admin);
    }

    function test_AcceptAdminRole_Run_NoApprovalRequired() public {
        // Begin transfer first
        vm.startPrank(admin);
        super.run_beginTransfer(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL2), newAdmin, false);
        vm.stopPrank();

        // Get the delay schedule and wait for it to pass
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1);

        // Accept admin role with approval required = false
        vm.startPrank(newAdmin);
        super.run_acceptAdmin(address(rlcLiquidityUnifier), address(rlcCrosschainToken), address(iexecLayerZeroBridgeL2), false);
        vm.stopPrank();
        assertEq(IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).defaultAdmin(), newAdmin);
        assertEq(IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL2)).defaultAdmin(), newAdmin);
        
        // Verify that RLCLiquidityUnifier admin was not affected
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
    }

    function test_AcceptAdminRole_RevertWhen_WrongAddressTriesToAccept() public {
        vm.startPrank(admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1);

        // Try to accept with wrong address
        address wrongAddress = makeAddr("wrongAddress");
        vm.startPrank(wrongAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, wrongAddress
            )
        );
        super.exposed_acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_AcceptAdminRole_RevertWhen_DelayNotElapsed() public {
        vm.startPrank(admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();

        // Try to accept immediately without waiting for the delay
        vm.startPrank(newAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, 1)
        );
        super.exposed_acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }
}
