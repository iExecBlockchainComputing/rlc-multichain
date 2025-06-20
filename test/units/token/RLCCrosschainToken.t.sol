// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../../script/RLCCrosschainToken.s.sol";
import {IERC7802} from "../../../src/interfaces/IERC7802.sol";
import {RLCCrosschainToken} from "../../../src/token/RLCCrosschainToken.sol";

contract RLCCrosschainTokenTest is Test {
    address owner = makeAddr("owner");
    address upgrader = makeAddr("upgrader");
    address bridge = makeAddr("bridge");
    address bridge2 = makeAddr("bridge2");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address anyone = makeAddr("anyone");
    uint256 amount = 100e9; // 100 RLC
    uint256 amount2 = 200e9; // 200 RLC
    uint256 amount3 = 300e9; // 300 RLC

    bytes32 private bridgeTokenRoleId;

    RLCCrosschainToken private crossChainToken;

    function setUp() public {
        crossChainToken = RLCCrosschainToken(
            new RLCCrosschainTokenDeployScript().deploy(
                "RLC Crosschain Token", "RLC", owner, upgrader, address(new CreateX()), keccak256("salt")
            )
        );
        bridgeTokenRoleId = crossChainToken.TOKEN_BRIDGE_ROLE();
    }

    // ============ initialize ============

    function test_RevertWhen_InitializedMoreThanOnce() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        crossChainToken.initialize("Foo", "BAR", owner, upgrader);
    }

    // ============ supportsInterface ============

    function test_SupportErc7802Interface() public view {
        assertEq(type(IERC7802).interfaceId, bytes4(0x33331994));
        assertTrue(crossChainToken.supportsInterface(type(IERC7802).interfaceId));
    }

    // ============ crosschainMint ============

    function test_MintForOneUserFromOneBridge() public {
        _authorizeBridge(bridge);
        // Check the initial state.
        assertEq(crossChainToken.totalSupply(), 0);
        // Expect events to be emitted.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        // Send mint request from the bridge.
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(crossChainToken.totalSupply(), amount);
        assertEq(crossChainToken.balanceOf(user), amount);
        assertEq(crossChainToken.balanceOf(bridge), 0);
    }

    function test_MintForOneUserFromOneBridgeMultipleTimes() public {
        _authorizeBridge(bridge);
        // Check the initial state.
        assertEq(crossChainToken.totalSupply(), 0);
        // Mint 1
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Mint 2
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(crossChainToken.totalSupply(), 2 * amount);
        assertEq(crossChainToken.balanceOf(user), 2 * amount);
        assertEq(crossChainToken.balanceOf(bridge), 0);
    }

    function test_MintForOneUserFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        assertEq(crossChainToken.totalSupply(), 0);
        // Bridge 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        // Send mint request from the bridge.
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Bridge 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        // Send mint request from the bridge.
        vm.prank(bridge2);
        crossChainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(crossChainToken.totalSupply(), 2 * amount);
        assertEq(crossChainToken.balanceOf(user), 2 * amount);
        assertEq(crossChainToken.balanceOf(bridge), 0);
        assertEq(crossChainToken.balanceOf(bridge2), 0);
    }

    function test_MintForMultipleUsersFromOneBridge() public {
        _authorizeBridge(bridge);
        assertEq(crossChainToken.totalSupply(), 0);
        // User 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // User 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge);
        vm.prank(bridge);
        crossChainToken.crosschainMint(user2, amount2);
        // User 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge);
        vm.prank(bridge);
        crossChainToken.crosschainMint(user3, amount3);
        // Check that tokens are minted.
        assertEq(crossChainToken.totalSupply(), amount + amount2 + amount3);
        assertEq(crossChainToken.balanceOf(user), amount);
        assertEq(crossChainToken.balanceOf(user2), amount2);
        assertEq(crossChainToken.balanceOf(user3), amount3);
        assertEq(crossChainToken.balanceOf(bridge), 0);
    }

    function test_MintForMultipleUsersFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        assertEq(crossChainToken.totalSupply(), 0);
        // Bridge 1, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        crossChainToken.crosschainMint(user, amount);
        // Bridge 1, user 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge2);
        vm.prank(bridge2);
        crossChainToken.crosschainMint(user2, amount2);
        // Bridge 2, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        vm.prank(bridge2);
        crossChainToken.crosschainMint(user, amount);
        // Bridge 2, user 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge2);
        vm.prank(bridge2);
        crossChainToken.crosschainMint(user3, amount3);
        // Check that tokens are minted.
        assertEq(crossChainToken.totalSupply(), 2 * amount + amount2 + amount3);
        assertEq(crossChainToken.balanceOf(user), 2 * amount); // Bridge 1 and bridge 2
        assertEq(crossChainToken.balanceOf(user2), amount2); // Bridge 1
        assertEq(crossChainToken.balanceOf(user3), amount3); // Bridge 2
        assertEq(crossChainToken.balanceOf(bridge), 0);
        assertEq(crossChainToken.balanceOf(bridge2), 0);
    }

    function test_RevertWhen_UnauthorizedCaller() public {
        assertEq(crossChainToken.balanceOf(user), 0);
        assertEq(crossChainToken.totalSupply(), 0);
        // Attempt to mint tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anyone, bridgeTokenRoleId)
        );
        vm.prank(anyone);
        crossChainToken.crosschainMint(user, amount);
        // Check that no tokens were minted.
        assertEq(crossChainToken.balanceOf(user), 0);
        assertEq(crossChainToken.totalSupply(), 0);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        _authorizeBridge(bridge);
        assertEq(crossChainToken.balanceOf(address(0)), 0);
        assertEq(crossChainToken.totalSupply(), 0);
        // Attempt to mint tokens the zero address.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(bridge);
        crossChainToken.crosschainMint(address(0), amount);
        // Check that no tokens were minted.
        assertEq(crossChainToken.balanceOf(address(0)), 0);
        assertEq(crossChainToken.totalSupply(), 0);
    }

    // ============ upgradeToAndCall ============

    function test_RevertWhen_UnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                crossChainToken.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorizedUpgrader);
        crossChainToken.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // TODO cosschainBurn

    // Helper functions

    /**
     * Grant the TOKEN_BRIDGE_ROLE to the specified bridge address.
     * @param bridgeAddress Address of the bridge to authorize.
     */
    function _authorizeBridge(address bridgeAddress) internal {
        vm.prank(owner);
        crossChainToken.grantRole(bridgeTokenRoleId, bridgeAddress);
    }
}
