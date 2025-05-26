// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../script/RLCOFT.s.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {ITokenSpender} from "../src/ITokenSpender.sol";
import {RLCOFTTestSetup} from "./utils/RLCOFTTestSetup.sol";

contract RLCOFTTest is RLCOFTTestSetup {
    RLCOFT public rlcOft;

    address public owner = makeAddr("owner");
    address public bridge = makeAddr("bridge");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Events to test
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Custom errors from OpenZeppelin
    error EnforcedPause();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);

    function setUp() public {
        // Set up environment variables for the deployment
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Test");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLCT");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", "0x6EDCE65403992e310A62460808c4b910D972f10f");

        // Deploy the contract using the deployment script
        rlcOft = RLCOFT(_forkArbitrumTestnetAndDeploy());

        vm.startPrank(owner);
        rlcOft.grantRole(rlcOft.BRIDGE_ROLE(), bridge);
        vm.stopPrank();

        vm.startPrank(bridge);
        rlcOft.mint(user1, 1000 * 10 ** 9);
        rlcOft.mint(user2, 500 * 10 ** 9);
        vm.stopPrank();
    }

    // ============ Deployment Tests ============
    function test_Deployment() public view {
        assertEq(rlcOft.name(), "RLC OFT Test");
        assertEq(rlcOft.symbol(), "RLCT");
        assertEq(rlcOft.decimals(), 9);
        assertEq(rlcOft.totalSupply(), 1500 * 10 ** 9); // 1000 + 500
    }

    // ============ Pausable Tests ============
    function test_PauseByPauser() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);

        vm.prank(pauser);
        rlcOft.pause();

        assertTrue(rlcOft.paused());
    }

    function test_RevertwhenPausedByUnauthorizedSender() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.PAUSER_ROLE()));
        vm.prank(user1);
        rlcOft.pause();
    }

    function test_UnpauseByPauser() public {
        // First pause
        vm.prank(pauser);
        rlcOft.pause();
        assertTrue(rlcOft.paused());

        // Then unpause
        vm.expectEmit(true, false, false, false);
        emit Unpaused(pauser);

        vm.prank(pauser);
        rlcOft.unpause();

        assertFalse(rlcOft.paused());
    }

    function test_UnpauseUnauthorized() public {
        vm.prank(pauser);
        rlcOft.pause();

        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.PAUSER_ROLE()));
        vm.prank(user1);
        rlcOft.unpause();
    }

    function test_RevertWhenTransferDuringPause() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user1);
        rlcOft.transfer(user2, 100 * 10 ** 9);
    }

    function test_TransferFromWhenPaused() public {
        // First approve
        vm.prank(user1);
        rlcOft.approve(user2, 100 * 10 ** 9);

        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to transferFrom - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user2);
        rlcOft.transferFrom(user1, user2, 100 * 10 ** 9);
    }

    function test_MintWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to mint - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.mint(user1, 100 * 10 ** 9);
    }

    function test_BurnWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to burn - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.burn(100 * 10 ** 9);
    }

    function test_TransferWhenNotPaused() public {
        uint256 transferAmount = 100 * 10 ** 9;
        uint256 initialBalance1 = rlcOft.balanceOf(user1);
        uint256 initialBalance2 = rlcOft.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, transferAmount);

        vm.prank(user1);
        bool success = rlcOft.transfer(user2, transferAmount);

        assertTrue(success);
        assertEq(rlcOft.balanceOf(user1), initialBalance1 - transferAmount);
        assertEq(rlcOft.balanceOf(user2), initialBalance2 + transferAmount);
    }
}
