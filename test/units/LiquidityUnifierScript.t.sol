// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {Deploy as LiquidityUnifierDeployScript} from "../../script/LiquidityUnifier.s.sol";
import {LiquidityUnifier} from "../../src/LiquidityUnifier.sol";

contract LiquidityUnifierTest is Test {
    address private rlcToken = makeAddr("RLC Token");
    address private createx = address(new CreateX());
    bytes32 private salt = keccak256("salt");
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    LiquidityUnifierDeployScript private deployer = new LiquidityUnifierDeployScript();

    function setUp() public {}

    function test_Deploy() public {
        address liquidityUnifierAddress = deployer.deploy(rlcToken, admin, upgrader, createx, salt);
        LiquidityUnifier liquidityUnifier = LiquidityUnifier(liquidityUnifierAddress);
        assertEq(liquidityUnifier.owner(), admin);
        assertEq(address(liquidityUnifier.RLC_TOKEN()), rlcToken);
        assertEq(liquidityUnifier.hasRole(liquidityUnifier.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(liquidityUnifier.hasRole(liquidityUnifier.UPGRADER_ROLE(), upgrader), true);
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
