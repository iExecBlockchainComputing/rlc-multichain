// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {MessagingFee, SendParam, IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {IexecLayerZeroBridgeHarness} from "../../mocks/IexecLayerZeroBridgeHarness.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/utils/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";
import {RLCCrosschainToken} from "../../../../src/RLCCrosschainToken.sol";
import {RLCLiquidityUnifier} from "../../../../src/RLCLiquidityUnifier.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";

contract IexecLayerZeroBridgeTest is TestHelperOz5 {
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridgeHarness private iexecLayerZeroBridgeEthereum; // A chain with approval required.
    IexecLayerZeroBridgeHarness private iexecLayerZeroBridgeChainX;
    RLCCrosschainToken private rlcCrosschainToken;
    RLCLiquidityUnifier private rlcLiquidityUnifier;
    RLCMock private rlcToken;

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

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointSource = address(endpoints[SOURCE_EID]); // Source endpoint for Sepolia - Destination endpoint for Arbitrum Sepolia
        address lzEndpointDestination = address(endpoints[DEST_EID]); // Source endpoint for Arbitrum Sepolia - Destination endpoint for Sepolia

        TestUtils.DeploymentResult memory deploymentResult = TestUtils.setupDeployment(
            TestUtils.DeploymentParams({
                iexecLayerZeroBridgeContractName: "IexecLayerZeroBridgeHarness",
                lzEndpointSource: lzEndpointSource,
                lzEndpointDestination: lzEndpointDestination,
                initialAdmin: admin,
                initialUpgrader: upgrader,
                initialPauser: pauser
            })
        );

        address iexecLayerZeroBridgeEthereumAddress = address(deploymentResult.iexecLayerZeroBridgeWithApproval);
        address iexecLayerZeroBridgeChainXAddress = address(deploymentResult.iexecLayerZeroBridgeWithoutApproval);

        iexecLayerZeroBridgeEthereum = IexecLayerZeroBridgeHarness(iexecLayerZeroBridgeEthereumAddress);
        iexecLayerZeroBridgeChainX = IexecLayerZeroBridgeHarness(iexecLayerZeroBridgeChainXAddress);
        rlcToken = deploymentResult.rlcToken;
        rlcCrosschainToken = deploymentResult.rlcCrosschainToken;
        rlcLiquidityUnifier = deploymentResult.rlcLiquidityUnifier;

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = iexecLayerZeroBridgeEthereumAddress; // Index 0 → EID 1
        contracts[1] = iexecLayerZeroBridgeChainXAddress; // Index 1 → EID 2
        vm.startPrank(admin);
        wireOApps(contracts);
        vm.stopPrank();

        // ### Setup for chainX ###
        // Authorize the bridge to mint/burn tokens.
        vm.startPrank(admin);
        rlcCrosschainToken.grantRole(rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeChainXAddress);
        vm.stopPrank();

        // Mint RLC tokens to user1
        vm.prank(iexecLayerZeroBridgeChainXAddress);
        rlcCrosschainToken.crosschainMint(user1, INITIAL_BALANCE);

        // ### Setup for Ethereum Mainnet ###
        // Authorize the bridge to lock/unLock tokens.
        vm.startPrank(admin);
        rlcLiquidityUnifier.grantRole(rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeEthereumAddress);
        vm.stopPrank();
        // Transfer initial RLC balance to user1
        rlcToken.transfer(user1, INITIAL_BALANCE);

        //Add label to make logs more readable
        vm.label(iexecLayerZeroBridgeEthereumAddress, "iexecLayerZeroBridgeEthereum");
        vm.label(iexecLayerZeroBridgeChainXAddress, "iexecLayerZeroBridgeChainX");
        vm.label(address(rlcToken), "rlcToken");
        vm.label(address(rlcCrosschainToken), "rlcCrosschainToken");
        vm.label(address(rlcLiquidityUnifier), "rlcLiquidityUnifier");
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
    //TODO: Add more tests for send functionality, in both directions

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============
    function test_SendToken_WhenOperational_WithApproval() public {
        vm.prank(user1);
        rlcToken.approve(address(iexecLayerZeroBridgeEthereum), TRANSFER_AMOUNT);
        _test_SendToken_WhenOperational(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    function test_SendToken_WhenOperational_WithoutApproval() public {
        _test_SendToken_WhenOperational(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    function _test_SendToken_WhenOperational(
        IexecLayerZeroBridgeHarness iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) internal {
        IERC20 token = IERC20(tokenAddress);

        // Check initial balances
        uint256 initialBalance = token.balanceOf(user1);
        assertEq(initialBalance, INITIAL_BALANCE, "Initial balance should match expected amount");

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) = TestUtils.prepareSend(
            iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, approvalRequired ? DEST_EID : SOURCE_EID
        );

        // For approval flow, expect Transfer event from ERC20 token
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(user1, approvalRequired ? address(rlcLiquidityUnifier) : address(0), TRANSFER_AMOUNT);

        if (!approvalRequired) {
            // For non-approval flow, expect CrosschainBurn event
            vm.expectEmit(true, true, true, true);
            emit IERC7802.CrosschainBurn(user1, TRANSFER_AMOUNT, address(iexecLayerZeroBridge));
        }

        // Expect OFTSent event from the bridge (this should be emitted by the parent OFT contract)
        vm.expectEmit(false, true, true, true);
        emit IOFT.OFTSent(
            bytes32(0), // ignore this value
            sendParam.dstEid,
            user1,
            TRANSFER_AMOUNT,
            TRANSFER_AMOUNT
        );

        // Send tokens
        vm.prank(user1);
        vm.deal(user1, fee.nativeFee);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned/locked
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT, "Tokens should be deducted from sender");
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeChainX.pause();
    }

    function test_Pause_BlocksAllTransfers() public {
        // TODO make check outbound and inbound transfers.
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, SOURCE_EID);

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        iexecLayerZeroBridgeChainX.unpause();
        vm.stopPrank();

        // Should now work normally
        test_SendToken_WhenOperational_WithoutApproval();
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridgeChainX.pause();
        iexecLayerZeroBridgeChainX.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, SOURCE_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Outbount transfer pause) ============

    function test_PauseOutboundTransfers_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeChainX.pauseOutboundTransfers();
    }

    function test_PauseOutboundTransfers_BlocksOutboundOnly() public {
        // Pause outbound transfers
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pauseOutboundTransfers();

        // Verify state
        assertFalse(iexecLayerZeroBridgeChainX.paused());
        assertTrue(iexecLayerZeroBridgeChainX.outbountTransfersPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, SOURCE_EID);

        // Attempt to send tokens - should revert with EnforcedOutboundTransfersPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedOutboundTransfersPause.selector);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_unpauseOutboundTransfers_RestoresboundgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridgeChainX.pauseOutboundTransfers();

        iexecLayerZeroBridgeChainX.unpauseOutboundTransfers();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridgeChainX.paused());
        assertFalse(iexecLayerZeroBridgeChainX.outbountTransfersPaused());

        test_SendToken_WhenOperational_WithoutApproval();
    }

    // ============ token and approvalRequired ============
    function test_ReturnsApprovalRequired_WithApproval() public view {
        assertEq(iexecLayerZeroBridgeEthereum.approvalRequired(), true, "approvalRequired() should return true");
    }

    function test_ReturnsApprovalRequired_WithoutApproval() public view {
        assertEq(iexecLayerZeroBridgeChainX.approvalRequired(), false, "approvalRequired() should return false");
    }

    function test_ReturnsBridgeableTokenAddress_WithApproval() public view {
        assertEq(
            iexecLayerZeroBridgeEthereum.token(),
            address(rlcToken),
            "token() should return the correct token contract address"
        );
    }

    function test_ReturnsBridgeableTokenAddress_WithoutApproval() public view {
        assertEq(
            iexecLayerZeroBridgeChainX.token(),
            address(rlcCrosschainToken),
            "token() should return the correct token contract address"
        );
    }

    // ============ _credit ============
    function test_credit_SuccessfulMintToUser() public {
        // Test successful minting to a regular user address
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        // Expect the Transfer & CrosschainMint event
        vm.expectEmit(true, true, true, true, address(rlcCrosschainToken));
        emit IERC20.Transfer(address(0), user2, TRANSFER_AMOUNT);
        vm.expectEmit(true, true, true, true, address(rlcCrosschainToken));
        emit IERC7802.CrosschainMint(user2, TRANSFER_AMOUNT, address(iexecLayerZeroBridgeChainX));

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2),
            initialBalance + TRANSFER_AMOUNT,
            "User balance should increase by mint amount"
        );
    }

    function test_credit_SendToDeadAddressInsteadOfZeroAddress() public {
        // Fuzz test with different addresses including zero address
        // Handle zero address redirection
        uint256 initialBalance = rlcCrosschainToken.balanceOf(address(0xdead));
        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(address(0), TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(address(0xdead)),
            initialBalance + TRANSFER_AMOUNT,
            "Actual recipient balance should increase"
        );

        assertEq(rlcCrosschainToken.balanceOf(address(0)), 0, "Zero address balance should remain zero");
    }

    function testFuzz_credit_Amount(uint256 amount) public {
        // Fuzz test with different amounts for testing edge case (0 & max RLC supply)
        uint256 totalSupply = 87_000_000 * 10 ** 9; // 87 million tokens with 9 decimals
        vm.assume(amount <= totalSupply);

        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);
        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, amount, SOURCE_EID);

        assertEq(amountReceived, amount, "Amount received should equal mint amount");
        assertEq(
            rlcCrosschainToken.balanceOf(user2), initialBalance + amount, "User balance should increase by mint amount"
        );
    }

    function test_credit_RevertsWhenPaused() public {
        // Test that _credit reverts when contract is fully paused
        // Pause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);
    }

    function test_credit_WorksWhenOutboundTransfersPaused() public {
        // Test that _credit still works when only sends are paused (Level 2 pause)
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        // Pause only sends
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pauseOutboundTransfers();

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, TRANSFER_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, TRANSFER_AMOUNT, address(iexecLayerZeroBridgeChainX));

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + TRANSFER_AMOUNT, "User balance should increase");
    }

    function test_credit_WorksAfterUnpause() public {
        // Test that _credit works after unpausing
        uint256 initialBalance = rlcCrosschainToken.balanceOf(user2);

        // Pause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        // Verify it's paused
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);

        // Unpause the contract
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.unpause();

        // Now it should work
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), user2, TRANSFER_AMOUNT);
        vm.expectEmit(true, true, true, true);
        emit IERC7802.CrosschainMint(user2, TRANSFER_AMOUNT, address(iexecLayerZeroBridgeChainX));

        uint256 amountReceived = iexecLayerZeroBridgeChainX.exposed_credit(user2, TRANSFER_AMOUNT, SOURCE_EID);

        assertEq(amountReceived, TRANSFER_AMOUNT, "Amount received should equal mint amount");
        assertEq(rlcCrosschainToken.balanceOf(user2), initialBalance + TRANSFER_AMOUNT, "User balance should increase");
    }
}
