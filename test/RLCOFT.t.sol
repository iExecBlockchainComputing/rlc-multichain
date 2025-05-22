// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../script/RLCOFT.s.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {ITokenSpender} from "../src/ITokenSpender.sol";

contract RLCOFTTest is Test {
    RLCOFT public rlcOft;
    
    address public owner;
    address public pauser;
    address public user1;
    address public user2;
    
    // Events to test
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    function setUp() public {
        vm.createSelectFork("https://arbitrum-sepolia.gateway.tenderly.com");

        // Create addresses using makeAddr
        owner = makeAddr("owner");
        pauser = makeAddr("pauser");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        
        // Set up environment variables for the deployment
        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Test");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLCT");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", vm.toString('LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS'));
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));
        
        // Deploy the contract using the deployment script
        RLCOFTDeploy deployer = new RLCOFTDeploy();
        address deployedAddress = deployer.run();
        rlcOft = RLCOFT(deployedAddress);

        // Mint some tokens for testing
        vm.prank(owner);
        rlcOft.mint(user1, 1000 * 10**9); // 1000 tokens with 9 decimals
        
        vm.prank(owner);
        rlcOft.mint(user2, 500 * 10**9); // 500 tokens with 9 decimals
    }

    // ============ Pausable Tests ============
    function testPauseByPauser() public {
        vm.expectEmit(true, false, false, false);
        emit Paused(pauser);
        
        vm.prank(pauser);
        rlcOft.pause();
        
        assertTrue(rlcOft.paused());
    }
    
    function testPauseUnauthorized() public {
        vm.expectRevert();
        vm.prank(user1);
        rlcOft.pause();
    }
    
    function testUnpauseByPauser() public {
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
    
    function testUnpauseUnauthorized() public {
        vm.prank(pauser);
        rlcOft.pause();
        
        vm.expectRevert();
        vm.prank(user1);
        rlcOft.unpause();
    }
    
    function testTransferWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();
        
        // Try to transfer - should fail
        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        rlcOft.transfer(user2, 100 * 10**9);
    }
    
    function testTransferFromWhenPaused() public {
        // First approve
        vm.prank(user1);
        rlcOft.approve(user2, 100 * 10**9);
        
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();
        
        // Try to transferFrom - should fail
        vm.expectRevert("Pausable: paused");
        vm.prank(user2);
        rlcOft.transferFrom(user1, user2, 100 * 10**9);
    }
    
    function testMintWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();
        
        // Try to mint - should fail
        vm.expectRevert("Pausable: paused");
        vm.prank(owner);
        rlcOft.mint(user1, 100 * 10**9);
    }
    
    function testBurnWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();
        
        // Try to burn - should fail
        vm.expectRevert("Pausable: paused");
        vm.prank(user1);
        rlcOft.burn(100 * 10**9);
    }
    
    function testTransferWhenNotPaused() public {
        uint256 transferAmount = 100 * 10**9;
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
