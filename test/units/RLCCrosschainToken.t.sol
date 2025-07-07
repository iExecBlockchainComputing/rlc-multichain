// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Deploy as RLCCrosschainTokenDeployScript} from "../../script/RLCCrosschainToken.s.sol";
import {RLCCrosschainToken} from "../../src/RLCCrosschainToken.sol";
import {ITokenSpender} from "../../src/interfaces/ITokenSpender.sol";

contract RLCCrosschainTokenTest is Test {
    address admin = makeAddr("admin");
    address upgrader = makeAddr("upgrader");
    address bridge = makeAddr("bridge");
    address bridge2 = makeAddr("bridge2");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address anyone = makeAddr("anyone");
    address spender = makeAddr("spender");
    uint256 amount = 100e9; // 100 RLC
    uint256 amount2 = 200e9; // 200 RLC
    uint256 amount3 = 300e9; // 300 RLC
    uint256 allowance = 123e9; // 123 RLC
    bytes approveAndCallData = bytes("data");

    bytes32 private bridgeTokenRoleId;

    RLCCrosschainToken private rlcCrosschainToken;

    function setUp() public {
        rlcCrosschainToken = RLCCrosschainToken(
            new RLCCrosschainTokenDeployScript().deploy(
                "iEx.ec Network Token", "RLC", admin, upgrader, address(new CreateX()), keccak256("salt")
            )
        );
        bridgeTokenRoleId = rlcCrosschainToken.TOKEN_BRIDGE_ROLE();

        //Add label to make logs more readable
        vm.label(address(rlcCrosschainToken), "rlcCrosschainToken");
    }

    // ============ initialize ============

    function test_RevertWhen_InitializedMoreThanOnce() public {
        vm.expectRevert(abi.encodeWithSelector(Initializable.InvalidInitialization.selector));
        rlcCrosschainToken.initialize("Foo", "BAR", admin, upgrader);
    }

    // ============ approveAndCall ============

    function test_ApproveAndCall() public {
        _mockSpenderCall(approveAndCallData);
        // Expect approval event.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, allowance);
        // Approve the spender to spend tokens and call its receiveApproval function.
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(spender, allowance, approveAndCallData);
        // Check allowance.
        assertEq(rlcCrosschainToken.allowance(user, spender), allowance);
    }

    function test_ApproveAndCallWithEmptyData() public {
        _mockSpenderCall(new bytes(0));
        // Expect approval event.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, allowance);
        // Approve the spender to spend tokens and call its receiveApproval function.
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(spender, allowance, "");
        // Check allowance.
        assertEq(rlcCrosschainToken.allowance(user, spender), allowance);
    }

    function test_ApproveAndCallWithZeroAllowance() public {
        _mockSpenderCall(approveAndCallData);
        // Expect approval event.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, 0);
        // Approve the spender.
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(spender, 0, approveAndCallData);
        // Check allowance.
        assertEq(rlcCrosschainToken.allowance(user, spender), 0);
    }

    function test_ApproveAndCallWithMaxUintAllowance() public {
        _mockSpenderCall(approveAndCallData);
        // Expect approval event.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, type(uint256).max);
        // Approve the spender with max uint allowance.
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(spender, type(uint256).max, approveAndCallData);
        // Check allowance.
        assertEq(rlcCrosschainToken.allowance(user, spender), type(uint256).max);
    }

    function test_ApproveAndCallShouldOverrideAllowanceAmount() public {
        uint256 allowance2 = 456e9; // 456 RLC
        _mockSpenderCall(approveAndCallData);
        vm.startPrank(user);
        // 1st call
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, allowance);
        rlcCrosschainToken.approveAndCall(spender, allowance, approveAndCallData);
        assertEq(rlcCrosschainToken.allowance(user, spender), allowance);
        // 2nd call
        vm.expectEmit(true, true, true, true);
        emit IERC20.Approval(user, spender, allowance2);
        rlcCrosschainToken.approveAndCall(spender, allowance2, approveAndCallData);
        assertEq(rlcCrosschainToken.allowance(user, spender), allowance2);
        vm.stopPrank();
    }

    function test_RevertWhen_ApproveAndCallWithZeroSpenderAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(address(0), allowance, approveAndCallData);
    }

    function test_RevertWhen_ApproveAndCallFromZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidApprover.selector, address(0)));
        vm.prank(address(0));
        rlcCrosschainToken.approveAndCall(spender, allowance, approveAndCallData);
    }

    function test_RevertWhen_CallToTheSpenderReverts() public {
        vm.mockCallRevert(
            spender,
            abi.encodeWithSelector(
                ITokenSpender.receiveApproval.selector, user, allowance, address(rlcCrosschainToken), approveAndCallData
            ),
            new bytes(0)
        );
        vm.expectRevert();
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(spender, allowance, approveAndCallData);
    }

    function test_RevertWhen_SpenderIsNotAContract() public {
        address eoaSpender = makeAddr("EOA"); // No mocking to simulate an EOA.
        vm.expectRevert();
        vm.prank(user);
        rlcCrosschainToken.approveAndCall(eoaSpender, allowance, approveAndCallData);
    }

    // ============ crosschainMint ============

    function test_MintForOneUserFromOneBridge() public {
        _authorizeBridge(bridge);
        // Check the initial state.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Expect events to be emitted.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        // Send mint request from the bridge.
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(rlcCrosschainToken.totalSupply(), amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        assertEq(rlcCrosschainToken.balanceOf(bridge), 0);
    }

    function test_MintForOneUserFromOneBridgeMultipleTimes() public {
        _authorizeBridge(bridge);
        // Check the initial state.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Mint 1
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Mint 2
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(bridge), 0);
    }

    function test_MintForOneUserFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Bridge 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        // Send mint request from the bridge.
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Bridge 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        // Send mint request from the bridge.
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Check that tokens are minted.
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(bridge), 0);
        assertEq(rlcCrosschainToken.balanceOf(bridge2), 0);
    }

    function test_MintForMultipleUsersFromOneBridge() public {
        _authorizeBridge(bridge);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // User 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // User 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user2, amount2);
        // User 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user3, amount3);
        // Check that tokens are minted.
        assertEq(rlcCrosschainToken.totalSupply(), amount + amount2 + amount3);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        assertEq(rlcCrosschainToken.balanceOf(user2), amount2);
        assertEq(rlcCrosschainToken.balanceOf(user3), amount3);
        assertEq(rlcCrosschainToken.balanceOf(bridge), 0);
    }

    function test_MintForMultipleUsersFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Bridge 1, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Bridge 2, user 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, amount2, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainMint(user2, amount2);
        // Bridge 2, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Bridge 2, user 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user3, amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user3, amount3, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainMint(user3, amount3);
        // Check that tokens are minted.
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount + amount2 + amount3);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount); // Bridge 1 and bridge 2
        assertEq(rlcCrosschainToken.balanceOf(user2), amount2); // Bridge 1
        assertEq(rlcCrosschainToken.balanceOf(user3), amount3); // Bridge 2
        assertEq(rlcCrosschainToken.balanceOf(bridge), 0);
        assertEq(rlcCrosschainToken.balanceOf(bridge2), 0);
    }

    function test_RevertWhen_UnauthorizedCaller() public {
        assertEq(rlcCrosschainToken.balanceOf(user), 0);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Attempt to mint tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anyone, bridgeTokenRoleId)
        );
        vm.prank(anyone);
        rlcCrosschainToken.crosschainMint(user, amount);
        // Check that no tokens were minted.
        assertEq(rlcCrosschainToken.balanceOf(user), 0);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_RevertWhen_MintToZeroAddress() public {
        _authorizeBridge(bridge);
        assertEq(rlcCrosschainToken.balanceOf(address(0)), 0);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Attempt to mint tokens the zero address.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(address(0), amount);
        // Check that no tokens were minted.
        assertEq(rlcCrosschainToken.balanceOf(address(0)), 0);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    // ============ crosschainBurn ============

    function test_BurnForOneUserFromOneBridge() public {
        _authorizeBridge(bridge);
        _mintForUser(user, amount);
        // Check the initial state.
        assertEq(rlcCrosschainToken.totalSupply(), amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        // Expect events to be emitted.
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        // Send burn request from the bridge.
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        assertEq(rlcCrosschainToken.balanceOf(user), 0);
    }

    function test_BurnForOneUserFromOneBridgeMultipleTimes() public {
        _authorizeBridge(bridge);
        _mintForUser(user, 2 * amount);
        // Check the initial state.
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount);

        // Burn 1
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        // Burn 2
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_BurnForOneUserFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        _mintForUser(user, 2 * amount);
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount);
        // Bridge 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        // Bridge 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_BurnForMultipleUsersFromOneBridge() public {
        _authorizeBridge(bridge);
        _mintForUser(user, amount);
        _mintForUser(user2, amount2);
        _mintForUser(user3, amount3);
        // User 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // User 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user2, address(0), amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user2, amount2, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user2, amount2);
        // User 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user3, address(0), amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user3, amount3, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user3, amount3);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_BurnForMultipleUsersFromMultipleBridges() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        _mintForUser(user, 2 * amount);
        _mintForUser(user2, amount2);
        _mintForUser(user3, amount3);
        assertEq(rlcCrosschainToken.totalSupply(), 2 * amount + amount2 + amount3);
        assertEq(rlcCrosschainToken.balanceOf(user), 2 * amount);
        assertEq(rlcCrosschainToken.balanceOf(user2), amount2);
        assertEq(rlcCrosschainToken.balanceOf(user3), amount3);
        // Bridge 1, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Bridge 2, user 2
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user2, address(0), amount2);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user2, amount2, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainBurn(user2, amount2);
        // Bridge 2, user 1
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Bridge 2, user 3
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user3, address(0), amount3);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user3, amount3, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainBurn(user3, amount3);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_BurnForUserEvenWhenMintIsDoneByDifferentBridge() public {
        _authorizeBridge(bridge);
        _authorizeBridge(bridge2);
        assertEq(rlcCrosschainToken.totalSupply(), 0);
        // Bridge 1 mints
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user, amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user, amount, bridge);
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(user, amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        // Bridge 2 burns
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user, address(0), amount);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainBurn(user, amount, bridge2);
        vm.prank(bridge2);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Check that tokens are burned.
        assertEq(rlcCrosschainToken.totalSupply(), 0);
    }

    function test_RevertWhen_UnauthorizedBurnCaller() public {
        _authorizeBridge(bridge);
        _mintForUser(user, amount);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
        // Attempt to burn tokens from an unauthorized account.
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, anyone, bridgeTokenRoleId)
        );
        vm.prank(anyone);
        rlcCrosschainToken.crosschainBurn(user, amount);
        // Check that tokens were not burned.
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
    }

    function test_RevertWhen_BurnFromZeroAddress() public {
        _authorizeBridge(bridge);
        // Attempt to burn tokens from the zero address.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(address(0), amount);
    }

    function test_RevertWhen_BurnMoreThanBalance() public {
        _authorizeBridge(bridge);
        _mintForUser(user, amount);
        // Attempt to burn more than balance
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, user, amount, amount + 1)
        );
        vm.prank(bridge);
        rlcCrosschainToken.crosschainBurn(user, amount + 1);
        assertEq(rlcCrosschainToken.balanceOf(user), amount);
    }

    // ============ supportsInterface ============

    function test_SupportErc7802Interface() public view {
        assertEq(type(IERC7802).interfaceId, bytes4(0x33331994));
        assertTrue(rlcCrosschainToken.supportsInterface(type(IERC7802).interfaceId));
    }

    // ============ decimals ============

    function test_DecimalsShouldBeTheSameAsTheRlcToken() public view {
        assertEq(rlcCrosschainToken.decimals(), 9, "Decimals should be the same as the RLC token (9)");
    }

    // ============ upgradeToAndCall ============

    function test_RevertWhen_UnauthorizedUpgrader() public {
        address unauthorizedUpgrader = makeAddr("unauthorized");
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                unauthorizedUpgrader,
                rlcCrosschainToken.UPGRADER_ROLE()
            )
        );
        vm.prank(unauthorizedUpgrader);
        rlcCrosschainToken.upgradeToAndCall(makeAddr("newImpl"), "");
    }

    // Helper functions

    /**
     * Grant the TOKEN_BRIDGE_ROLE to the specified bridge address.
     * @param bridgeAddress Address of the bridge to authorize.
     */
    function _authorizeBridge(address bridgeAddress) internal {
        vm.prank(admin);
        rlcCrosschainToken.grantRole(bridgeTokenRoleId, bridgeAddress);
    }

    /**
     * Mint `amount` tokens to the specified user using the bridge.
     * @param userAddress Address of the user to mint tokens for.
     */
    function _mintForUser(address userAddress, uint256 mintAmount) internal {
        vm.prank(bridge);
        rlcCrosschainToken.crosschainMint(userAddress, mintAmount);
    }

    /**
     * Mocks the call to the spender contract's receiveApproval function with no return data.
     * @param data The data to pass to the spender contract.
     */
    function _mockSpenderCall(bytes memory data) internal {
        // Set up a mock spender contract.
        vm.mockCall(
            spender,
            abi.encodeWithSelector(
                ITokenSpender.receiveApproval.selector, user, allowance, address(rlcCrosschainToken), data
            ),
            new bytes(0) // No return data expected.
        );
    }
}
