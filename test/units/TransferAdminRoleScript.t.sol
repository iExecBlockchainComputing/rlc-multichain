// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {BeginTransferAdminRole, AcceptAdminRole} from "../../script/TransferAdminRole.s.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../script/RLCLiquidityUnifier.s.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";

// Test wrapper contract to expose internal functions

contract BeginTransferAdminRoleHarness is BeginTransferAdminRole {
    function exposed_beginTransfer(address contractAddress, address newAdmin, string memory contractName) public {
        beginTransfer(contractAddress, newAdmin, contractName);
    }


    function exposed_validateAdminTransfer(address currentDefaultAdmin, address newAdmin) public pure {
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
    }
}

// Test wrapper contract to expose internal functions
contract AcceptAdminRoleHarness is AcceptAdminRole {
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

    TestUtils.DeploymentResult deployment;

    RLCLiquidityUnifierDeployScript private liquidityUnifierDeployer;
    RLCCrosschainTokenDeployScript private crosschainTokenDeployer;

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
    }

    // Override run functions to resolve inheritance conflict
    function run() external pure override(BeginTransferAdminRole, AcceptAdminRole) {
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
        super.exposed_beginTransfer(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier"
        );
        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // Current admin should still be the initial admin until acceptance
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        vm.stopPrank();
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
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), bytes32(0)));
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

    function test_AcceptAdminRole_RevertWhen_WrongAddressTriesToAccept() public {
        vm.startPrank(admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1); 

        // Try to accept with wrong address
        address wrongAddress = makeAddr("wrongAddress");
        vm.startPrank(wrongAddress);
        vm.expectRevert(abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, wrongAddress));
        super.exposed_acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_AcceptAdminRole_RevertWhen_DelayNotElapsed() public {
        vm.startPrank(admin);
        super.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();

        // Try to accept immediately without waiting for the delay
        vm.startPrank(newAdmin);
        vm.expectRevert(abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, 1));
        super.exposed_acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }
}