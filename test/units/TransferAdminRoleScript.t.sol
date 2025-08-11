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
import {CreateX} from "@createx/contracts/CreateX.sol";
import {ConfigLib} from "./../../script/lib/ConfigLib.sol";

contract TransferAdminRoleScriptTest is TestHelperOz5, BeginTransferAdminRole, AcceptAdminRole {
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
        rlcLiquidityUnifier = deployment.rlcLiquidityUnifier;
        rlcCrosschainToken = deployment.rlcCrosschainToken;
        iexecLayerZeroBridgeL1 = deployment.iexecLayerZeroBridgeWithApproval;
        iexecLayerZeroBridgeL2 = deployment.iexecLayerZeroBridgeWithoutApproval;
        params = TestUtils.emptyConfigParams();
    }

    // Override run functions to resolve inheritance conflict
    function run() external pure override(BeginTransferAdminRole, AcceptAdminRole) {
        // This function should not be called directly in tests
        // Use super.beginTransferForAllContracts() or super.run_acceptAdmin() instead
        revert("Use specific test functions instead");
    }

    // ====== BeginTransferAdminRole.validateAdminTransfer ======
    function test_ValidateAdminTransfer() public {
        vm.startPrank(admin);
        super.beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_ValidateAdminTransfer_RevertWhen_NewAdminIsZeroAddress() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: new admin cannot be zero address");
        this.externalCallBeginTransfer(address(rlcLiquidityUnifier), address(0), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_ValidateAdminTransfer_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        this.externalCallBeginTransfer(address(rlcLiquidityUnifier), admin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    // ====== BeginTransferAdminRole.beginTransfer ======
    function test_BeginTransfer_LiquidityUnifier() public {
        vm.startPrank(admin);
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        super.beginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        // Verify that the admin transfer has been initiated
        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, newAdmin);

        // Current admin should still be the initial admin until acceptance
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
        vm.stopPrank();
    }

    function test_BeginTransferAdminRole_Run_ApprovalRequired() public {
        configureParams(true);
        vm.startPrank(admin);
        super.beginTransferForAllContracts(params, newAdmin);
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
        configureParams(false);
        vm.startPrank(admin);
        super.beginTransferForAllContracts(params, newAdmin);
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
        this.externalCallBeginTransfer(address(rlcLiquidityUnifier), address(0), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_BeginTransfer_RevertWhen_NewAdminIsSameAsCurrentAdmin() public {
        vm.startPrank(admin);
        vm.expectRevert("BeginTransferAdminRole: New admin must be different from current admin");
        this.externalCallBeginTransfer(address(rlcLiquidityUnifier), admin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_BeginTransfer_RevertWhen_NotAuthorizedToTransferAdmin() public {
        address unauthorizedUser = makeAddr("unauthorizedUser");
        vm.startPrank(unauthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, address(this), bytes32(0))
        );
        this.externalCallBeginTransfer(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    // ====== AcceptAdminRole.acceptContractAdmin ======
    function test_AcceptAdminRole_LiquidityUnifier() public {
        beginTransferAsAdmin(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        waitForAdminTransferDelay(address(rlcLiquidityUnifier));

        vm.prank(newAdmin);
        super.acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);

        (address pendingAdmin,) = IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).pendingDefaultAdmin();
        assertEq(pendingAdmin, address(0));
    }

    function test_AcceptAdminRole_Run_ApprovalRequired() public {
        beginTransferForAllContractsAsAdmin(newAdmin, true);
        vm.stopPrank();

        // Get the delay schedule and wait for it to pass
        waitForAdminTransferDelay(address(rlcLiquidityUnifier));

        // Accept admin role with approval required = true
        configureParams(true);
        vm.startPrank(newAdmin);
        super.acceptAdminRoleTransfer(params);
        vm.stopPrank();

        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), newAdmin);
        assertEq(IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL1)).defaultAdmin(), newAdmin);

        // Verify that RLCCrosschainToken admin was not affected
        assertEq(IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).defaultAdmin(), admin);
    }

    function test_AcceptAdminRole_Run_NoApprovalRequired() public {
        beginTransferForAllContractsAsAdmin(newAdmin, false);
        waitForAdminTransferDelay(address(rlcCrosschainToken));

        // Accept admin role with approval required = false
        configureParams(false);
        vm.startPrank(newAdmin);
        super.acceptAdminRoleTransfer(params);
        vm.stopPrank();
        assertEq(IAccessControlDefaultAdminRules(address(rlcCrosschainToken)).defaultAdmin(), newAdmin);
        assertEq(IAccessControlDefaultAdminRules(address(iexecLayerZeroBridgeL2)).defaultAdmin(), newAdmin);

        // Verify that RLCLiquidityUnifier admin was not affected
        assertEq(IAccessControlDefaultAdminRules(address(rlcLiquidityUnifier)).defaultAdmin(), admin);
    }

    function test_AcceptAdminRole_RevertWhen_WrongAddressTriesToAccept() public {
        beginTransferAsAdmin(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");
        waitForAdminTransferDelay(address(rlcLiquidityUnifier));

        // Try to accept with wrong address
        address wrongAddress = makeAddr("wrongAddress");
        vm.startPrank(wrongAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControlDefaultAdminRules.AccessControlInvalidDefaultAdmin.selector, wrongAddress
            )
        );
        super.acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    function test_AcceptAdminRole_RevertWhen_DelayNotElapsed() public {
        beginTransferAsAdmin(address(rlcLiquidityUnifier), newAdmin, "RLCLiquidityUnifier");

        // Try to accept immediately without waiting for the delay
        vm.startPrank(newAdmin);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControlDefaultAdminRules.AccessControlEnforcedDefaultAdminDelay.selector, 1)
        );
        super.acceptContractAdmin(address(rlcLiquidityUnifier), "RLCLiquidityUnifier");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            HELPER FUNCTION
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice External wrapper for beginTransfer to enable proper revert testing
     * @dev This function is necessary for testing revert scenarios because:
     * When testing internal functions that call `super`,
     *    Foundry's vm.expectRevert doesn't properly catch reverts from internal function calls.
     *    This is because internal calls don't create new call frames that Foundry can intercept.
     *
     * This pattern allows vm.expectRevert to work correctly by ensuring the revert happens
     * in a separate call frame that Foundry can detect and validate.
     *
     * @param contractAddress The address of the contract to transfer admin rights
     * @param _newAdminAddr The address of the new admin
     * @param contractName The name of the contract for logging purposes
     */
    function externalCallBeginTransfer(address contractAddress, address _newAdminAddr, string memory contractName)
        external
    {
        super.beginTransfer(contractAddress, _newAdminAddr, contractName);
    }

    /**
     * @notice Helper function to configure params based on approval requirement
     * @param _approvalRequired Whether approval is required for the transfer
     */
    function configureParams(bool _approvalRequired) internal {
        params.approvalRequired = _approvalRequired;
        params.iexecLayerZeroBridgeAddress =
            _approvalRequired ? address(iexecLayerZeroBridgeL1) : address(iexecLayerZeroBridgeL2);
        params.rlcLiquidityUnifierAddress = _approvalRequired ? address(rlcLiquidityUnifier) : address(0);
        params.rlcCrosschainTokenAddress = _approvalRequired ? address(0) : address(rlcCrosschainToken);
    }

    /**
     * @notice Helper function to initiate the admin transfer process
     * @param _newAdmin The address of the new admin
     * @param _approvalRequired Whether approval is required for the transfer
     */
    function beginTransferForAllContractsAsAdmin(address _newAdmin, bool _approvalRequired) internal {
        configureParams(_approvalRequired);
        vm.startPrank(admin);
        super.beginTransferForAllContracts(params, _newAdmin);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to initiate the admin transfer process
     * @param _contractAddress The address of the contract to transfer admin rights
     * @param _newAdmin The address of the new admin
     * @param _contractName The name of the contract
     */
    function beginTransferAsAdmin(address _contractAddress, address _newAdmin, string memory _contractName) internal {
        vm.startPrank(admin);
        super.beginTransfer(_contractAddress, _newAdmin, _contractName);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to wait for the admin transfer delay to pass
     * @param contractAddress The contract address to check the pending admin schedule
     */
    function waitForAdminTransferDelay(address contractAddress) internal {
        (, uint48 acceptSchedule) = IAccessControlDefaultAdminRules(contractAddress).pendingDefaultAdmin();
        vm.warp(acceptSchedule + 1);
    }
}
