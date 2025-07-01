// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/utils/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {RLCLiquidityUnifier} from "../../../../src/RLCLiquidityUnifier.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";

/**
 * Test Script for the IexecLayerZeroBridge on Ethereum Mainnet.
 * In this case, IexecLayerZeroBridge should be connected to
 * RLCLiquidityUnifier contract deployed on the same chain.
 */
contract IexecLayerZeroBridgeOnMainnetTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridgeEthereum;
    IexecLayerZeroBridge private iexecLayerZeroBridgeChainX;
    RLCMock private rlcToken;
    RLCLiquidityUnifier private rlcLiquidityUnifier;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private admin = makeAddr("admin");
    address private upgrader = makeAddr("upgrader");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
    string private name = "iEx.ec Network Token";
    string private symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointSource = address(endpoints[SOURCE_EID]);
        address lzEndpointDestination = address(endpoints[DEST_EID]);

        (iexecLayerZeroBridgeEthereum, iexecLayerZeroBridgeChainX, rlcToken,, rlcLiquidityUnifier) =
            TestUtils.setupDeployment(name, symbol, lzEndpointSource, lzEndpointDestination, admin, upgrader, pauser);

        address iexecLayerZeroBridgeEthereumAddress = address(iexecLayerZeroBridgeEthereum);
        address iexecLayerZeroBridgeChainXAddress = address(iexecLayerZeroBridgeChainX);
        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = iexecLayerZeroBridgeEthereumAddress;
        contracts[1] = iexecLayerZeroBridgeChainXAddress;
        vm.startPrank(admin);
        wireOApps(contracts);
        vm.stopPrank();

        // Authorize the bridge to mint/burn tokens.
        vm.startPrank(admin);
        rlcLiquidityUnifier.grantRole(rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeEthereumAddress);
        vm.stopPrank();

        // Transfer initial RLC balance to user1
        rlcToken.transfer(user1, INITIAL_BALANCE);
    }

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============
    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeEthereum, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.startPrank(user1);
        rlcToken.approve(address(iexecLayerZeroBridgeEthereum), TRANSFER_AMOUNT); // For Stargate compatibility, user should approve iexecLayerZeroBridge
        iexecLayerZeroBridgeEthereum.send{value: fee.nativeFee}(sendParam, fee, payable(user1));
        vm.stopPrank();

        // Verify source state - tokens should be burned
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    //TODO: Add more tests for send functionality, in both directions

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeEthereum.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridgeEthereum.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeEthereum, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeEthereum.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridgeEthereum.pause();

        iexecLayerZeroBridgeEthereum.unpause();
        vm.stopPrank();

        // Should now work normally
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridgeEthereum.pause();
        iexecLayerZeroBridgeEthereum.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeEthereum, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.startPrank(user1);
        rlcToken.approve(address(iexecLayerZeroBridgeEthereum), TRANSFER_AMOUNT); // For Stargate compatibility, user should approve iexecLayerZeroBridge
        iexecLayerZeroBridgeEthereum.send{value: fee.nativeFee}(sendParam, fee, payable(user1));
        vm.stopPrank();

        // Verify source state - tokens should be burned
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============

    function test_PauseSend_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeEthereum.pauseSend();
    }

    function test_PauseSend_BlocksOutgoingOnly() public {
        // Pause send
        vm.prank(pauser);
        iexecLayerZeroBridgeEthereum.pauseSend();

        // Verify state
        assertFalse(iexecLayerZeroBridgeEthereum.paused());
        assertTrue(iexecLayerZeroBridgeEthereum.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeEthereum, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.startPrank(user1);
        rlcToken.approve(address(iexecLayerZeroBridgeEthereum), TRANSFER_AMOUNT); // For Stargate compatibility, user should approve iexecLayerZeroBridge
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridgeEthereum.send{value: fee.nativeFee}(sendParam, fee, payable(user1));
        vm.stopPrank();

        // Verify no tokens were burned
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridgeEthereum.pauseSend();

        iexecLayerZeroBridgeEthereum.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridgeEthereum.paused());
        assertFalse(iexecLayerZeroBridgeEthereum.sendPaused());

        test_SendToken_WhenOperational();
    }

    // ============ token and approvalRequired ============
    function test_ReturnsBridgeableTokenAddress() public view {
        // On Ethereum Mainnet
        address bridgeableToken = iexecLayerZeroBridgeEthereum.token();
        assertEq(bridgeableToken, address(rlcToken), "token() should return the RLC token address");
    }

    function test_ReturnsApprovalRequired() public {
        // Simulate Ethereum Mainnet chain ID
        vm.chainId(1);
        bool requiresApproval = iexecLayerZeroBridgeEthereum.approvalRequired();
        assertTrue(requiresApproval, "approvalRequired() should return true on Ethereum Mainnet");
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
