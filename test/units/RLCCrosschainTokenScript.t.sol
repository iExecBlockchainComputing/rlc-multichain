// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private createx = address(new CreateX());
    bytes32 private salt = keccak256("salt");
    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    string private name = "iEx.ec Network Token";
    string private symbol = "RLC";
    RLCCrosschainTokenDeployScript private deployer = new RLCCrosschainTokenDeployScript();

    function setUp() public {}

    function test_Deploy() public {
        address crosschainTokenAddress = deployer.deploy(name, symbol, admin, upgrader, createx, salt);
        RLCCrosschainToken crossChainToken = RLCCrosschainToken(crosschainTokenAddress);
        assertEq(crossChainToken.name(), name);
        assertEq(crossChainToken.symbol(), symbol);
        assertEq(crossChainToken.owner(), admin);
        assertEq(crossChainToken.hasRole(crossChainToken.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(crossChainToken.hasRole(crossChainToken.UPGRADER_ROLE(), upgrader), true);

        // Make sure the contract has been initialized.
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        crossChainToken.initialize(name, symbol, admin, upgrader);
        // TODO check that the proxy address is saved.
    }

    // Makes sure create2 deployment is well implemented.
    function test_RevertWhen_TwoDeploymentsWithTheSameSalt() public {
        address random = makeAddr("random");
        deployer.deploy(name, symbol, admin, upgrader, createx, salt);
        vm.expectRevert(abi.encodeWithSignature("FailedContractCreation(address)", createx));
        deployer.deploy("Foo", "BAR", random, random, createx, salt);
    }
}
