// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test, console} from "forge-std/Test.sol";
import {Deploy as RLCOFTDeploy, Configure as RLCOFTConfigure} from "../script/RLCOFT.s.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {ITokenSpender} from "../src/ITokenSpender.sol";
import {RLCOFTTestSetup} from "./utils/RLCOFTTestSetup.sol";
import {SendParam, MessagingFee, MessagingReceipt, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import { TestHelperOz5 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

contract RLCOFTTest is RLCOFTTestSetup {
    RLCOFT public rlcOft;

    address public owner = makeAddr("owner");
    address public bridge = makeAddr("bridge");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public spender = makeAddr("spender");

    // Test constants
    uint32 public constant DESTINATION_EID = 40161; // Ethereum mainnet EID
    uint256 public constant TRANSFER_AMOUNT = 100 * 10 ** 9;
    uint256 public constant MINT_AMOUNT = 1000 * 10 ** 9;

    // Events to test
    event Paused(address account);
    event Unpaused(address account);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event OFTSent(bytes32 indexed guid, uint32 dstEid, address indexed fromAddress, uint256 amountSentLD, uint256 amountReceivedLD);
    event OFTReceived(bytes32 indexed guid, uint32 srcEid, address indexed toAddress, uint256 amountReceivedLD);

    // Custom errors from OpenZeppelin and LayerZero
    error EnforcedPause();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error SlippageExceeded(uint256 amountLD, uint256 minAmountLD);

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
        rlcOft.mint(user1, MINT_AMOUNT);
        rlcOft.mint(user2, 500 * 10 ** 9);
        vm.stopPrank();
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

    // ============ ERC20 Pausable Tests ============
    function test_RevertWhenTransferDuringPause() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user1);
        rlcOft.transfer(user2, TRANSFER_AMOUNT);
    }

    function test_TransferFromWhenPaused() public {
        // First approve
        vm.prank(user1);
        rlcOft.approve(user2, TRANSFER_AMOUNT);

        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to transferFrom - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user2);
        rlcOft.transferFrom(user1, user2, TRANSFER_AMOUNT);
    }

    function test_MintWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to mint - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.mint(user1, TRANSFER_AMOUNT);
    }

    function test_BurnWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Try to burn - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(bridge);
        rlcOft.burn(TRANSFER_AMOUNT);
    }

    function test_TransferWhenNotPaused() public {
        uint256 initialBalance1 = rlcOft.balanceOf(user1);
        uint256 initialBalance2 = rlcOft.balanceOf(user2);

        vm.expectEmit(true, true, false, true);
        emit Transfer(user1, user2, TRANSFER_AMOUNT);

        vm.prank(user1);
        bool success = rlcOft.transfer(user2, TRANSFER_AMOUNT);

        assertTrue(success);
        assertEq(rlcOft.balanceOf(user1), initialBalance1 - TRANSFER_AMOUNT);
        assertEq(rlcOft.balanceOf(user2), initialBalance2 + TRANSFER_AMOUNT);
    }

    // ============ OFT Pausable Tests ============
    function test_SendWhenPaused() public {
        // First set up peer connection (simplified for test)
        vm.prank(owner);
        rlcOft.setPeer(DESTINATION_EID, bytes32(uint256(uint160(address(rlcOft)))));

        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Create send parameters
        SendParam memory sendParam = SendParam({
            dstEid: DESTINATION_EID,
            to: bytes32(uint256(uint160(user2))),
            amountLD: TRANSFER_AMOUNT,
            minAmountLD: TRANSFER_AMOUNT,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        MessagingFee memory fee = MessagingFee({
            nativeFee: 0.001 ether,
            lzTokenFee: 0
        });

        // Fund the user for the transaction
        vm.deal(user1, 1 ether);

        // Try to send - should fail with EnforcedPause() custom error
        vm.expectRevert(EnforcedPause.selector);
        vm.prank(user1);
        rlcOft.send{value: fee.nativeFee}(sendParam, fee, user1);
    }

    function test_SendWhenNotPaused() public {
        // First set up peer connection
        vm.prank(owner);
        rlcOft.setPeer(DESTINATION_EID, bytes32(uint256(uint160(address(rlcOft)))));

        // Create send parameters
        SendParam memory sendParam = SendParam({
            dstEid: DESTINATION_EID,
            to: bytes32(uint256(uint160(user2))),
            amountLD: TRANSFER_AMOUNT,
            minAmountLD: TRANSFER_AMOUNT,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });

        // Get quote for the send operation
        MessagingFee memory fee = rlcOft.quoteSend(sendParam, false);
        
        // Fund the user for the transaction
        vm.deal(user1, fee.nativeFee + 1 ether);

        // Send should work when not paused
        vm.prank(user1);
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) = 
            rlcOft.send{value: fee.nativeFee}(sendParam, fee, user1);

        // Verify the send was successful
        assertEq(oftReceipt.amountSentLD, TRANSFER_AMOUNT);
        assertEq(oftReceipt.amountReceivedLD, TRANSFER_AMOUNT);
        assertTrue(msgReceipt.guid != bytes32(0));
    }

    function test_LzReceiveWhenPaused() public {
        // Pause the contract
        vm.prank(pauser);
        rlcOft.pause();

        // Create mock origin data
        Origin memory origin = Origin({
            srcEid: DESTINATION_EID,
            sender: bytes32(uint256(uint160(address(rlcOft)))),
            nonce: 1
        });

        // Create mock message data (simplified OFT message format)
        bytes memory message = abi.encodePacked(
            bytes32(uint256(uint160(user2))), // to address
            uint64(TRANSFER_AMOUNT / (10 ** (rlcOft.decimals() - rlcOft.sharedDecimals()))), // amount in shared decimals
            bytes("") // compose message
        );

        bytes32 guid = keccak256("test_guid");

        // Mock the endpoint to call _lzReceive
        vm.prank(address(rlcOft.endpoint()));
        
        // This should fail with EnforcedPause() when paused
        vm.expectRevert(EnforcedPause.selector);
        
        // We need to call the internal function through a mock or by simulating the endpoint call
        // Since _lzReceive is internal, we simulate it through the endpoint
        try rlcOft.lzReceive{gas: 200000}(
            origin,
            guid,
            message,
            address(0),
            ""
        ) {
            // Should not reach here when paused
            assertTrue(false, "Should have reverted with EnforcedPause");
        } catch (bytes memory reason) {
            // Verify it's the expected pause error
            bytes4 selector = bytes4(reason);
            assertEq(selector, EnforcedPause.selector);
        }
    }

    // ============ Bridge Role Tests ============
    function test_MintByBridge() public {
        uint256 initialBalance = rlcOft.balanceOf(user1);
        uint256 initialTotalSupply = rlcOft.totalSupply();

        vm.prank(bridge);
        rlcOft.mint(user1, TRANSFER_AMOUNT);

        assertEq(rlcOft.balanceOf(user1), initialBalance + TRANSFER_AMOUNT);
        assertEq(rlcOft.totalSupply(), initialTotalSupply + TRANSFER_AMOUNT);
    }

    function test_BurnByBridge() public {
        uint256 initialBalance = rlcOft.balanceOf(bridge);
        uint256 initialTotalSupply = rlcOft.totalSupply();

        // First mint some tokens to bridge
        vm.prank(bridge);
        rlcOft.mint(bridge, TRANSFER_AMOUNT);

        // Then burn them
        vm.prank(bridge);
        rlcOft.burn(TRANSFER_AMOUNT);

        assertEq(rlcOft.balanceOf(bridge), initialBalance);
        assertEq(rlcOft.totalSupply(), initialTotalSupply);
    }

    function test_MintUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.BRIDGE_ROLE()));
        vm.prank(user1);
        rlcOft.mint(user1, TRANSFER_AMOUNT);
    }

    function test_BurnUnauthorized() public {
        vm.expectRevert(abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, user1, rlcOft.BRIDGE_ROLE()));
        vm.prank(user1);
        rlcOft.burn(TRANSFER_AMOUNT);
    }
}
