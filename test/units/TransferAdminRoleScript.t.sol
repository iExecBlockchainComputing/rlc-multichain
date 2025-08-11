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

// Test wrapper contract to expose internal functions and override msg.sender

contract BeginTransferAdminRoleHarness is BeginTransferAdminRole {
    function exposed_beginTransfer(address contractAddress, address newAdmin, string memory contractName) public {
        beginTransfer(contractAddress, newAdmin, contractName);
    }

    function exposed_beginTransferAsAdmin(
        address contractAddress,
        address newAdmin,
        string memory contractName,
        address admin
    ) public {
        vm.startPrank(admin);
        beginTransfer(contractAddress, newAdmin, contractName);
        vm.stopPrank();
    }

    function exposed_validateAdminTransfer(address currentDefaultAdmin, address newAdmin) public pure {
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
    }
}

// Test wrapper contract to expose internal functions and override msg.sender
contract AcceptAdminRoleHarness is AcceptAdminRole {
    function exposed_acceptContractAdmin(address contractAddress, string memory contractName) public {
        acceptContractAdmin(contractAddress, contractName);
    }

    function exposed_acceptContractAdminAsUser(address contractAddress, string memory contractName, address user)
        public
    {
        vm.startPrank(user);
        acceptContractAdmin(contractAddress, contractName);
        vm.stopPrank();
    }
}

contract TransferAdminRoleScriptTest is TestHelperOz5 {
    using TestUtils for *;

    BeginTransferAdminRoleHarness private beginTransferScript;
    AcceptAdminRoleHarness private acceptAdminScript;

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

        beginTransferScript = new BeginTransferAdminRoleHarness();
        acceptAdminScript = new AcceptAdminRoleHarness();
    }

    // ====== BeginTransferAdminRole.validateAdminTransfer ======
    function test_ValidateAdminTransfer() public {
        // Test the validation function directly
        vm.startPrank(admin);

        // Should not revert with valid inputs
        beginTransferScript.exposed_validateAdminTransfer(admin, newAdmin);

        // Should revert with zero address
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        beginTransferScript.exposed_validateAdminTransfer(admin, address(0));

        // Should revert when new admin is same as current
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        beginTransferScript.exposed_validateAdminTransfer(admin, admin);

        vm.stopPrank();
    }

    // ====== BeginTransferAdminRole.beginTransfer ======
    function test_BeginTransferAdminRole_LiquidityUnifier() public {
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        beginTransferScript.exposed_beginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );
        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // Current admin should still be the initial admin until acceptance
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
    }

    // ====== AcceptAdminRole.acceptContractAdmin ======
    function test_AcceptAdminRole_LiquidityUnifier() public {
        beginTransferScript.exposed_beginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );

        // Get the delay schedule and wait for it to pass
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1); // Wait until after the scheduled time

        // Now accept as the new admin using the script wrapper
        acceptAdminScript.exposed_acceptContractAdminAsUser(address(rlcLiquidityUnifier), "RLCLiquidityUnifier", newAdmin);

        // Verify that the admin transfer has been completed
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);

        // Pending admin should be reset to zero
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
    }

    function test_AcceptAdminRole_RevertWhen_WrongAddressTriesToAcceptAdmin() public {
        beginTransferScript.exposed_beginTransferAsAdmin(
            address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier", admin
        );

        // Try to accept with wrong address using the script wrapper
        address wrongAddress = makeAddr("wrongAddress");

        vm.expectRevert(); // Should revert because only pending admin can accept
        acceptAdminScript.exposed_acceptContractAdminAsUser(
            address(rlcLiquidityUnifier), "RLCLiquidityUnifier", wrongAddress
        );
    }

    // ====== revert scenarios checks ======
    function test_RevertWhen_NewAdminIsZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        beginTransferScript.exposed_beginTransfer(address(rlcLiquidityUnifier), address(0), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        beginTransferScript.exposed_beginTransfer(address(rlcLiquidityUnifier), admin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_RevertWhen_NotAuthorizedToTransferAdmin() public {
        address unauthorizedUser = makeAddr("unauthorizedUser");
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(); // Should revert with access control error
        beginTransferScript.exposed_beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }
}
