// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {RLCCrosschainToken} from "../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private owner = makeAddr("owner");
    address private upgrader = makeAddr("upgrader");

    RLCCrosschainToken private crossChainToken;

    function setUp() public {
        crossChainToken = RLCCrosschainToken(
            new RLCCrosschainTokenDeployScript().deploy(
                "RLC Crosschain Token", "RLC", owner, upgrader, address(new CreateX()), keccak256("salt")
            )
        );
    }

    function test_RevertWhen_InitializedMoreThanOnce() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        crossChainToken.initialize("Foo", "BAR", owner, upgrader);
    }

    function test_SupportErc7802Interface() public view {
        assertTrue(type(IERC7802).interfaceId == bytes4(0x33331994));
        assertTrue(crossChainToken.supportsInterface(type(IERC7802).interfaceId));
    }

    function test_RevertWhen_UnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSignature(
                "AccessControlUnauthorizedAccount(address,bytes32)",
                unauthorizedUpgrader,
                crossChainToken.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorizedUpgrader);
        crossChainToken.upgradeToAndCall(makeAddr("newImpl"), "");
    }
}
