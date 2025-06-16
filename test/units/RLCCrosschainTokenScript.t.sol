// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {RLCCrosschainToken} from "../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private owner = makeAddr("owner");
    address private upgrader = makeAddr("upgrader");

    function setUp() public {}

    function test_Deploy() public {
        address crosschainTokenAddress = new RLCCrosschainTokenDeployScript().deploy(
            "RLC Token", "RLC", owner, upgrader, address(new CreateX()), keccak256("salt")
        );
        RLCCrosschainToken crossChainToken = RLCCrosschainToken(crosschainTokenAddress);
        assertEq(crossChainToken.name(), "RLC Token");
        assertEq(crossChainToken.symbol(), "RLC");
        assertEq(crossChainToken.owner(), owner);
        assertEq(crossChainToken.hasRole(crossChainToken.DEFAULT_ADMIN_ROLE(), owner), true);
        assertEq(crossChainToken.hasRole(crossChainToken.UPGRADER_ROLE(), upgrader), true);
        // TODO check that the proxy address is saved.
    }
}
