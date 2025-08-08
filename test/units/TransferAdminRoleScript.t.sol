// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {BeginTransferAdminRole, AcceptAdminRole} from "../../script/TransferAdminRole.s.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import {IAccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {TestUtils} from "./utils/TestUtils.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../script/RLCLiquidityUnifier.s.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";

// Test wrapper contract to expose internal functions
contract TestableBeginTransferAdminRole is BeginTransferAdminRole {
    function publicBeginTransfer(address contractAddress, address newAdmin, string memory contractName) public {
        beginTransfer(contractAddress, newAdmin, contractName);
    }

    function publicBeginTransferAsAdmin(
        address contractAddress,
        address newAdmin,
        string memory contractName,
        address admin
    ) public {
        vm.startPrank(admin);
        beginTransfer(contractAddress, newAdmin, contractName);
        vm.stopPrank();
    }

    function publicValidateAdminTransfer(address currentDefaultAdmin, address newAdmin) public pure {
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
    }
}

// Test wrapper contract to expose internal functions
contract TestableAcceptAdminRole is AcceptAdminRole {
    function publicAcceptContractAdmin(address contractAddress, string memory contractName) public {
        acceptContractAdmin(contractAddress, contractName);
    }

    function publicAcceptContractAdminAsUser(address contractAddress, string memory contractName, address user)
        public
    {
        vm.startPrank(user);
        acceptContractAdmin(contractAddress, contractName);
        vm.stopPrank();
    }
}

contract TransferAdminRoleScriptTest is TestHelperOz5 {
    using TestUtils for *;

    TestableBeginTransferAdminRole private beginTransferScript;
    TestableAcceptAdminRole private acceptAdminScript;

    // Test addresses
    address private newAdmin = makeAddr("newAdmin");
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    address private pauser = makeAddr("pauser");
    uint16 private sourceEndpointId = 1;
    uint16 private targetEndpointId = 2;
    RLCLiquidityUnifier rlcLiquidityUnifier;
    RLCCrosschainToken rlcCrosschainToken;

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
        rlcCrosschainToken = deployment.rlcCrosschainToken;

        beginTransferScript = new TestableBeginTransferAdminRole();
        acceptAdminScript = new TestableAcceptAdminRole();
    }

    // ====== revert scenarios checks ======
    function test_RevertWhen_NewAdminIsZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        beginTransferScript.publicBeginTransfer(address(rlcLiquidityUnifier), address(0), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        beginTransferScript.publicBeginTransfer(address(rlcLiquidityUnifier), admin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_RevertWhen_NotAuthorizedToTransferAdmin() public {
        address unauthorizedUser = makeAddr("unauthorizedUser");
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(); // Should revert with access control error
        beginTransferScript.publicBeginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_RevertWhen_WrongAddressTriesToAcceptAdmin() public {
        beginTransferScript.publicBeginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );

        // Try to accept with wrong address using the script wrapper
        address wrongAddress = makeAddr("wrongAddress");

        vm.expectRevert(); // Should revert because only pending admin can accept
        acceptAdminScript.publicAcceptContractAdminAsUser(
            address(rlcLiquidityUnifier), "RLCLiquidityUnifier", wrongAddress
        );
    }

    // ====== BeginTransferAdminRole.validateAdminTransfer ======
    function test_ValidateAdminTransfer() public {
        // Test the validation function directly
        vm.startPrank(admin);

        // Should not revert with valid inputs
        beginTransferScript.publicValidateAdminTransfer(admin, newAdmin);

        // Should revert with zero address
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        beginTransferScript.publicValidateAdminTransfer(admin, address(0));

        // Should revert when new admin is same as current
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        beginTransferScript.publicValidateAdminTransfer(admin, admin);

        vm.stopPrank();
    }

    // ====== BeginTransferAdminRole.beginTransfer ======
    function test_BeginTransferAdminRole_LiquidityUnifier() public {
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        beginTransferScript.publicBeginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );
        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // Current admin should still be the initial admin until acceptance
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
    }

    function test_BeginTransferAdminRole_CrosschainToken() public {
        assertEq(IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).defaultAdmin(), admin);
        beginTransferScript.publicBeginTransferAsAdmin(
            address(rlcCrosschainToken), newAdmin, "RLCCrosschainToken", admin
        );

        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);
    }

    // ====== AcceptAdminRole.acceptContractAdmin ======
    function test_AcceptAdminRole_LiquidityUnifier() public {
        beginTransferScript.publicBeginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );

        // Get the delay schedule and wait for it to pass
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1); // Wait until after the scheduled time

        // Now accept as the new admin using the script wrapper
        acceptAdminScript.publicAcceptContractAdminAsUser(address(rlcLiquidityUnifier), "RLCLiquidityUnifier", newAdmin);

        // Verify that the admin transfer has been completed
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);

        // Pending admin should be reset to zero
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
    }
}
