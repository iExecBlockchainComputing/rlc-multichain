// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {RLCCrosschainToken} from "../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private createx = address(new CreateX());
    bytes32 private salt = keccak256("salt");
    address private owner = makeAddr("owner");
    address private upgrader = makeAddr("upgrader");
    RLCCrosschainTokenDeployScript private deployer = new RLCCrosschainTokenDeployScript();

    function setUp() public {}

    function test_Deploy() public {
        address crosschainTokenAddress = deployer.deploy("RLC Crosschain Token", "RLC", owner, upgrader, createx, salt);
        RLCCrosschainToken crossChainToken = RLCCrosschainToken(crosschainTokenAddress);
        assertEq(crossChainToken.name(), "RLC Crosschain Token");
        assertEq(crossChainToken.symbol(), "RLC");
        assertEq(crossChainToken.owner(), owner);
        assertEq(crossChainToken.hasRole(crossChainToken.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(crossChainToken.hasRole(crossChainToken.UPGRADER_ROLE(), upgrader), true);
        // TODO check that the proxy address is saved.
    }

    // Makes sure create2 deployment is well implemented.
    function test_RevertWhenTwoDeploymentsWithTheSameSalt() public {
        console.log("CreateX address:", createx);
        address random = makeAddr("random");
        deployer.deploy("RLC Crosschain Token", "RLC", owner, upgrader, createx, salt);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", createx));
        deployer.deploy("Foo", "BAR", random, random, createx, salt);
    }
}
