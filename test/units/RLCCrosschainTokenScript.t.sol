// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCCrosschainToken} from "../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private createx;
    RLCCrosschainTokenDeployScript private deployScript;
    RLCCrosschainToken private token;

    address private owner = makeAddr("owner");
    address private upgrader = makeAddr("upgrader");

    function setUp() public {
        createx = address(new CreateX());
        deployScript = new RLCCrosschainTokenDeployScript();
    }

    function test_Deploy() public {
        RLCCrosschainToken crossChainToken = RLCCrosschainToken(
            deployScript.deploy(
                "RLC Token",
                "RLC",
                owner,
                upgrader,
                createx,
                keccak256("salt")
            )
        );
        assertEq(crossChainToken.name(), "RLC Token");
        assertEq(crossChainToken.symbol(), "RLC");
        assertEq(crossChainToken.owner(), owner);
        assertEq(crossChainToken.hasRole(crossChainToken.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(crossChainToken.hasRole(crossChainToken.UPGRADER_ROLE(), upgrader), true);
        // Check that re-initialization reverts
        vm.expectRevert(InvalidInitialization.selector);
        crossChainToken.initialize("Foo", "BAR", owner, upgrader);
        // TODO check that the proxy address is saved.
    }

    error InvalidInitialization();
}