// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {stdError} from "forge-std/StdError.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Deploy as RLCLiquidityUnifierDeployScript} from "../../script/RLCLiquidityUnifier.s.sol";
import {IRLCLiquidityUnifier} from "../../src/interfaces/IRLCLiquidityUnifier.sol";
import {RLCLiquidityUnifier} from "../../src/RLCLiquidityUnifier.sol";
import {RLCMock} from "./mocks/RLCMock.sol";

//TODO: Reduce number of asserts make on event - redundant
contract LiquidityUnifierTest is Test {
    address admin = makeAddr("admin");
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

    RLCLiquidityUnifier private rlcLiquidityUnifier;
    address private rlcLiquidityUnifierAddress;
    RLCMock private rlcToken;

    function setUp() public {
        rlcToken = new RLCMock();
        rlcLiquidityUnifier = RLCLiquidityUnifier(
            new RLCLiquidityUnifierDeployScript().deploy(
                address(rlcToken), admin, upgrader, address(new CreateX()), keccak256("salt")
            )
        );
        rlcLiquidityUnifierAddress = address(rlcLiquidityUnifier);
        bridgeTokenRoleId = rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE();

        //Add label to make logs more readable
        vm.label(address(rlcToken), "rlcToken");
        vm.label(rlcLiquidityUnifierAddress, "rlcLiquidityUnifier");
    }

    // ============ initialize ============

    function test_RevertWhen_InitializedMoreThanOnce() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rlcLiquidityUnifier.initialize(admin, upgrader);
    }

    // ============ crosschainMint ============

    function test_CrosschainMintForOneUserFromOneBridge() public {
        _authorizeBridge(bridge);

        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);

        // Expect the correct transfer and crosschainMint events
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);

        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);

        // Act
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainMint(user, amount);

        // Assert
        assertEq(rlcToken.balanceOf(user), amount);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), 0);
        assertEq(rlcToken.balanceOf(bridge), 0);
    }

    function test_CrosschainMintForOneUserFromOneBridgeMultipleTimes() public {
        _authorizeBridge(bridge);
        // Check the initial state.

        // Mint 1
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        _mintForUser(user, amount);
        // Mint 2
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        _mintForUser(user, amount);
        // Check that tokens are minted.
        assertEq(rlcToken.balanceOf(user), 2 * amount);
        assertEq(rlcToken.balanceOf(bridge), 0);
    }

    function test_CrosschainMintForOneUserFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);

        // Bridge 1
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        // Send mint request from the bridge.
        _mintForUser(user, amount);
        // Bridge 2
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        // Send mint request from the bridge.
        _mintForUser(bridge2, user, amount);
        // Check that tokens are minted.
        assertEq(rlcToken.balanceOf(user), 2 * amount);
        assertEq(rlcToken.balanceOf(bridge), 0);
        assertEq(rlcToken.balanceOf(bridge2), 0);
    }

    function test_CrosschainMintForMultipleUsersFromOneBridge() public {
        _authorizeBridge(bridge);

        // User 1
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        _mintForUser(user, amount);
        // User 2
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge);
        _mintForUser(user2, amount2);
        // User 3
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge);
        _mintForUser(user3, amount3);

        // Check that tokens are minted.
        assertEq(rlcToken.balanceOf(user), amount);
        assertEq(rlcToken.balanceOf(user2), amount2);
        assertEq(rlcToken.balanceOf(user3), amount3);
        assertEq(rlcToken.balanceOf(bridge), 0);
    }

    function test_CrosschainMintForMultipleUsersFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);

        // Bridge 1, user 1
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        _mintForUser(user, amount);
        // Bridge 2, user 2
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge2);
        _mintForUser(bridge2, user2, amount2);
        // Bridge 2, user 1
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        _mintForUser(bridge2, user, amount);
        // Bridge 2, user 3
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge2);
        _mintForUser(bridge2, user3, amount3);

        // Check that tokens are minted.
        assertEq(rlcToken.balanceOf(user), 2 * amount); // Bridge 1 and bridge 2
        assertEq(rlcToken.balanceOf(user2), amount2); // Bridge 1
        assertEq(rlcToken.balanceOf(user3), amount3); // Bridge 2
        assertEq(rlcToken.balanceOf(bridge), 0);
        assertEq(rlcToken.balanceOf(bridge2), 0);
    }

    function test_RevertWhen_UnauthorizedCaller() public {
        assertEq(rlcToken.balanceOf(user), 0);

        // Attempt to mint tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anyone, bridgeTokenRoleId)
        );
        vm.prank(anyone);
        rlcLiquidityUnifier.crosschainMint(user, amount);
        // Check that no tokens were minted.
        assertEq(rlcToken.balanceOf(user), 0);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        _authorizeBridge(bridge);
        assertEq(rlcToken.balanceOf(address(0)), 0);

        // Attempt to mint tokens the zero address.
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectRevert(abi.encodeWithSelector(IRLCLiquidityUnifier.ERC7802InvalidToAddress.selector, address(0)));
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainMint(address(0), amount);
        // Check that no tokens were minted.
        assertEq(rlcToken.balanceOf(address(0)), 0);
    }

    // ============ crosschainBurn ============

    function test_CrosschainBurnForOneUserFromOneBridge() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount);

        // Check the initial state.
        assertEq(rlcToken.balanceOf(user), amount);
        _approveLiquidityUnifier(user, amount);
        // Expect events to be emitted.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        // Send burn request from the bridge.
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), amount);
    }

    function test_CrosschainBurnForOneUserFromOneBridgeMultipleTimes() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, 2 * amount);

        // Check the initial state.
        assertEq(rlcToken.balanceOf(user), 2 * amount);

        // Approve the rlcLiquidityUnifier to spend tokens
        _approveLiquidityUnifier(user, 2 * amount);

        // Burn 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        assertEq(rlcToken.balanceOf(user), amount);

        // Burn 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), 2 * amount);
    }

    function test_CrosschainBurnForOneUserFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        rlcToken.transfer(user, 2 * amount);
        assertEq(rlcToken.balanceOf(user), 2 * amount);

        // Approve the rlcLiquidityUnifier to spend tokens
        _approveLiquidityUnifier(user, 2 * amount);

        // Bridge 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        assertEq(rlcToken.balanceOf(user), amount);

        // Bridge 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), 2 * amount);
    }

    function test_CrosschainBurnForMultipleUsersFromOneBridge() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount);
        rlcToken.transfer(user2, amount2);
        rlcToken.transfer(user3, amount3);

        // Approve the rlcLiquidityUnifier to spend tokens for each user
        _approveLiquidityUnifier(user, amount);
        _approveLiquidityUnifier(user2, amount2);
        _approveLiquidityUnifier(user3, amount3);

        // User 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);

        // User 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user2, rlcLiquidityUnifierAddress, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user2, amount2, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user2, amount2);

        // User 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user3, rlcLiquidityUnifierAddress, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user3, amount3, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user3, amount3);

        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
        assertEq(rlcToken.balanceOf(user2), 0);
        assertEq(rlcToken.balanceOf(user3), 0);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), amount + amount2 + amount3);
    }

    function test_CrosschainBurnForMultipleUsersFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        rlcToken.transfer(user, 2 * amount);
        rlcToken.transfer(user2, amount2);
        rlcToken.transfer(user3, amount3);
        assertEq(rlcToken.balanceOf(user), 2 * amount);
        assertEq(rlcToken.balanceOf(user2), amount2);
        assertEq(rlcToken.balanceOf(user3), amount3);

        // Approve the rlcLiquidityUnifier to spend tokens for each user
        _approveLiquidityUnifier(user, 2 * amount);
        _approveLiquidityUnifier(user2, amount2);
        _approveLiquidityUnifier(user3, amount3);

        // Bridge 1, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);

        // Bridge 2, user 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user2, rlcLiquidityUnifierAddress, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user2, amount2, bridge2);
        vm.prank(bridge2);
        rlcLiquidityUnifier.crosschainBurn(user2, amount2);

        // Bridge 2, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcLiquidityUnifier.crosschainBurn(user, amount);

        // Bridge 2, user 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user3, rlcLiquidityUnifierAddress, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user3, amount3, bridge2);
        vm.prank(bridge2);
        rlcLiquidityUnifier.crosschainBurn(user3, amount3);

        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
        assertEq(rlcToken.balanceOf(user2), 0);
        assertEq(rlcToken.balanceOf(user3), 0);
        assertEq(rlcToken.balanceOf(rlcLiquidityUnifierAddress), 2 * amount + amount2 + amount3);
    }

    function test_CrosschainBurnForUserEvenWhenMintIsDoneByDifferentBridge() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);

        // Bridge 1 mints
        rlcToken.transfer(rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(rlcLiquidityUnifierAddress, user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        _mintForUser(user, amount);
        assertEq(rlcToken.balanceOf(user), amount);

        // User approves rlcLiquidityUnifier to spend tokens
        _approveLiquidityUnifier(user, amount);

        // Bridge 2 burns
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, rlcLiquidityUnifierAddress, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcLiquidityUnifier.crosschainBurn(user, amount);

        // Check that tokens are burned.

        assertEq(rlcToken.balanceOf(user), 0);
    }

    function test_RevertWhen_UnauthorizedBurnCaller() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount);
        assertEq(rlcToken.balanceOf(user), amount);

        // Attempt to burn tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anyone, bridgeTokenRoleId)
        );
        vm.prank(anyone);
        rlcLiquidityUnifier.crosschainBurn(user, amount);

        // Check that tokens were not burned.
        assertEq(rlcToken.balanceOf(user), amount);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        _authorizeBridge(bridge);
        // Attempt to burn tokens from the zero address.
        vm.expectRevert(abi.encodeWithSelector(IRLCLiquidityUnifier.ERC7802InvalidFromAddress.selector, address(0)));
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(address(0), amount);
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount);

        // User approves more than they have
        _approveLiquidityUnifier(user, amount + 1);

        // Attempt to burn more than balance
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount + 1);
        assertEq(rlcToken.balanceOf(user), amount);
    }

    function test_RevertWhen_CrosschainBurn_BurnMoreThanAllowance() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount + 1);

        // User approves less than they have
        _approveLiquidityUnifier(user, amount);

        // Attempt to burn more than allowance
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount + 1);
        assertEq(rlcToken.balanceOf(user), amount + 1);
    }

    function test_RevertWhen_BurnWithoutUserApprove() public {
        _authorizeBridge(bridge);
        rlcToken.transfer(user, amount);

        // Attempt to burn without user approval
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(bridge);
        rlcLiquidityUnifier.crosschainBurn(user, amount);
        assertEq(rlcToken.balanceOf(user), amount);
    }

    // ============ decimals ============

    function test_DecimalsShouldBeTheSameAsTheRlcToken() public view {
        uint8 expectedDecimals = rlcToken.decimals();
        uint8 actualDecimals = rlcLiquidityUnifier.decimals();
        assertEq(actualDecimals, expectedDecimals, "decimals() should return the same value as RLC_TOKEN.decimals()");
        assertEq(actualDecimals, 9, "Decimals should equal 9");
    }

    // ============ supportsInterface ============

    function test_SupportErc7802Interface() public view {
        assertEq(type(IERC7802).interfaceId, bytes4(0x33331994));
        assertTrue(rlcLiquidityUnifier.supportsInterface(type(IERC7802).interfaceId));
    }

    // ============ upgradeToAndCall ============

    function test_RevertWhen_UnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                rlcLiquidityUnifier.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorizedUpgrader);
        rlcLiquidityUnifier.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // ============ helper functions ============
    //TODO: refactor this file to share test and helper functions with RLCCrosschain tests

    /**
     * Grant the TOKEN_BRIDGE_ROLE to the specified bridge address.
     * @param bridgeAddress Address of the bridge to authorize.
     */
    function _authorizeBridge(address bridgeAddress) internal {
        vm.prank(admin);
        rlcLiquidityUnifier.grantRole(bridgeTokenRoleId, bridgeAddress);
    }

    /**
     * Mint `amount` tokens to the specified user using the default bridge.
     * @param userAddress Address of the user to mint tokens for.
     * @param mintAmount Amount of tokens to mint.
     */
    function _mintForUser(address userAddress, uint256 mintAmount) internal {
        _mintForUser(bridge, userAddress, mintAmount);
    }

    /**
     * Mint `amount` tokens to the specified user using a specific bridge.
     * @param bridgeAddress Address of the bridge to use for minting.
     * @param userAddress Address of the user to mint tokens for.
     * @param mintAmount Amount of tokens to mint.
     */
    function _mintForUser(address bridgeAddress, address userAddress, uint256 mintAmount) internal {
        vm.prank(bridgeAddress);
        rlcLiquidityUnifier.crosschainMint(userAddress, mintAmount);
    }

    /**
     * Approve the RLCLiquidityUnifier to spend tokens on behalf of a user.
     * @param sender Address of the user approving.
     * @param approveAmount Amount of tokens to approve.
     */
    function _approveLiquidityUnifier(address sender, uint256 approveAmount) internal {
        vm.prank(sender);
        rlcToken.approve(rlcLiquidityUnifierAddress, approveAmount);
    }
}
