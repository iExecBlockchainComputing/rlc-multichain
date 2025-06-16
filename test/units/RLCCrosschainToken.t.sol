// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {IERC7802} from "../../src/interfaces/IERC7802.sol";
import {RLCCrosschainToken} from "../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address private owner = makeAddr("owner");
    address private upgrader = makeAddr("upgrader");
    address private bridge = makeAddr("bridge");
    address private user = makeAddr("user");
    address private anyone = makeAddr("anyone");
    uint256 amount = 100e9; // 100 RLC

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
        assertEq(type(IERC7802).interfaceId, bytes4(0x33331994));
        assertTrue(crossChainToken.supportsInterface(type(IERC7802).interfaceId));
    }

    function test_MintTokens() public {
        assertEq(crossChainToken.balanceOf(user), 0);
        assertEq(crossChainToken.balanceOf(bridge), 0);
        assertEq(crossChainToken.totalSupply(), 0);
        // Grant TOKEN_BRIDGE_ROLE to the bridge.
        bytes32 roleId = crossChainToken.TOKEN_BRIDGE_ROLE();
        vm.prank(owner);
        crossChainToken.grantRole(roleId, bridge);
        // Send mint request from the bridge.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(crossChainToken.balanceOf(user), amount);
        assertEq(crossChainToken.balanceOf(bridge), 0);
        assertEq(crossChainToken.totalSupply(), amount);
    }

    function test_RevertWhen_UnauthorizedMinter() public {
        assertEq(crossChainToken.balanceOf(user), 0);
        assertEq(crossChainToken.totalSupply(), 0);
        // Grant TOKEN_BRIDGE_ROLE to the bridge.
        bytes32 roleId = crossChainToken.TOKEN_BRIDGE_ROLE();
        vm.prank(owner);
        crossChainToken.grantRole(roleId, bridge);
        // Attempt to mint tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", anyone, roleId)
        );
        vm.prank(anyone);
        crossChainToken.crosschainMint(user, amount);
        // Check that no tokens were minted.
        assertEq(crossChainToken.balanceOf(user), 0);
        assertEq(crossChainToken.totalSupply(), 0);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        assertEq(crossChainToken.balanceOf(address(0)), 0);
        assertEq(crossChainToken.totalSupply(), 0);
        // Grant TOKEN_BRIDGE_ROLE to the bridge.
        bytes32 roleId = crossChainToken.TOKEN_BRIDGE_ROLE();
        vm.prank(owner);
        crossChainToken.grantRole(roleId, bridge);
        // Attempt to mint tokens the zero address.
        vm.expectRevert(
            abi.encodeWithSignature("ERC20InvalidReceiver(address)", address(0))
        );
        vm.prank(bridge);
        crossChainToken.crosschainMint(address(0), amount);
        // Check that no tokens were minted.
        assertEq(crossChainToken.balanceOf(address(0)), 0);
        assertEq(crossChainToken.totalSupply(), 0);
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
