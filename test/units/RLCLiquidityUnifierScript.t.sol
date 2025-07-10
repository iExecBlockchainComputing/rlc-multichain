// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../script/RLCLiquidityUnifier.s.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";

contract LiquidityUnifierTest is Test {
    address private rlcToken = makeAddr("RLC Token");
    address private createx = address(new CreateX());
    bytes32 private salt = keccak256("salt");
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    RLCLiquidityUnifierDeployScript private deployer = new RLCLiquidityUnifierDeployScript();

    function setUp() public {}

    function test_Deploy() public {
        // Check that CreateX salt is used to deploy the contract.
        vm.expectEmit(false, true, false, false);
        // CreateX uses a guarded salt (see CreateX._guard()), so we need to hash it to match the expected event.
        emit CreateX.ContractCreation(address(0), keccak256(abi.encode(salt)));
        address rlcLiquidityUnifierAddress = deployer.deploy(rlcToken, admin, upgrader, createx, salt);
        RLCLiquidityUnifier rlcLiquidityUnifier = RLCLiquidityUnifier(rlcLiquidityUnifierAddress);
        assertEq(rlcLiquidityUnifier.owner(), admin);
        assertEq(address(rlcLiquidityUnifier.RLC_TOKEN()), rlcToken);
        assertEq(rlcLiquidityUnifier.hasRole(rlcLiquidityUnifier.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(rlcLiquidityUnifier.hasRole(rlcLiquidityUnifier.UPGRADER_ROLE(), upgrader), true);
        // Make sure the contract has been initialized.
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rlcLiquidityUnifier.initialize(admin, upgrader);
        // TODO check that the proxy address is saved.
    }

    // Makes sure create2 deployment is well implemented.
    function test_RevertWhen_TwoDeploymentsWithTheSameSalt() public {
        address random = makeAddr("random");
        deployer.deploy(rlcToken, admin, upgrader, createx, salt);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", createx));
        deployer.deploy(rlcToken, random, random, createx, salt);
    }
}
