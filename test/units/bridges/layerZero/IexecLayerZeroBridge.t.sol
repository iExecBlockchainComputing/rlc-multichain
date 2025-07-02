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

contract IexecLayerZeroBridgeTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridgeEthereum;
    IexecLayerZeroBridge private iexecLayerZeroBridgeChainX;
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
    string private name = "iEx.ec Network Token";
    string private symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointSource = address(endpoints[SOURCE_EID]); // Source endpoint for Ethereum Mainnet - Destination endpoint for Arbitrum
        address lzEndpointDestination = address(endpoints[DEST_EID]); // Source endpoint for Arbitrum - Destination endpoint for Ethereum Mainnet

        (iexecLayerZeroBridgeEthereum, iexecLayerZeroBridgeChainX, rlcToken, rlcCrosschainToken, rlcLiquidityUnifier) =
            TestUtils.setupDeployment(name, symbol, lzEndpointSource, lzEndpointDestination, admin, upgrader, pauser);

        address iexecLayerZeroBridgeEthereumAddress = address(iexecLayerZeroBridgeEthereum);
        address iexecLayerZeroBridgeChainXAddress = address(iexecLayerZeroBridgeChainX);
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
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
    //TODO: Add more tests for send functionality, in both directions

    // ###############################################
    // With ApprovalRequired
    // ###############################################

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============
    function test_SendToken_WhenOperational_WithApproval() public {
        _test_SendToken_WhenOperational(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole_WithApproval() public {
        _test_Pause_OnlyPauserRole(iexecLayerZeroBridgeEthereum);
    }

    function test_Pause_BlocksOutgoingTransfers__WithApproval() public {
        _test_Pause_BlocksOutgoingTransfers(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    function test_Unpause_RestoresFullFunctionality_WithApproval() public {
        _test_Unpause_RestoresFullFunctionality(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused_WithApproval() public {
        _test_sendRLCWhenSourceLayerZeroBridgeUnpaused(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============
    function test_PauseSend_OnlyPauserRole_WithApproval() public {
        _test_PauseSend_OnlyPauserRole(iexecLayerZeroBridgeEthereum);
    }

    function test_PauseSend_BlocksOutgoingOnly_WithApproval() public {
        _test_PauseSend_BlocksOutgoingOnly(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers_WithApproval() public {
        _test_UnpauseSend_RestoresOutgoingTransfers(iexecLayerZeroBridgeEthereum, address(rlcToken), true);
    }

    // ============ token and approvalRequired ============

    function test_ReturnsApprovalRequired_WithApproval() public {
        _testReturnsApprovalRequired(iexecLayerZeroBridgeEthereum, true);
    }

    function test_ReturnsBridgeableTokenAddress_WithApproval() public view {
        _testBridgeableTokenAddress(iexecLayerZeroBridgeEthereum, address(rlcToken));
    }

    // ###############################################
    // Without ApprovalRequired
    // ###############################################

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============
    function test_SendToken_WhenOperational_WithoutApproval() public {
        _test_SendToken_WhenOperational(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole_WithoutApproval() public {
        _test_Pause_OnlyPauserRole(iexecLayerZeroBridgeChainX);
    }

    function test_Pause_BlocksOutgoingTransfers_WithoutApproval() public {
        _test_Pause_BlocksOutgoingTransfers(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    function test_Unpause_RestoresFullFunctionality_WithoutApproval() public {
        _test_Unpause_RestoresFullFunctionality(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused_WithoutApproval() public {
        _test_sendRLCWhenSourceLayerZeroBridgeUnpaused(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============
    function test_PauseSend_OnlyPauserRole_WithoutApproval() public {
        _test_PauseSend_OnlyPauserRole(iexecLayerZeroBridgeChainX);
    }

    function test_PauseSend_BlocksOutgoingOnly_WithoutApproval() public {
        _test_PauseSend_BlocksOutgoingOnly(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers_WithoutApproval() public {
        _test_UnpauseSend_RestoresOutgoingTransfers(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken), false);
    }

    // ============ token and approvalRequired ============
    function test_ReturnsApprovalRequired_WithoutApproval() public {
        _testReturnsApprovalRequired(iexecLayerZeroBridgeChainX, false);
    }

    function test_ReturnsBridgeableTokenAddress_WithoutApproval() public view {
        _testBridgeableTokenAddress(iexecLayerZeroBridgeChainX, address(rlcCrosschainToken));
    }

    // ###############################################
    // Common functions
    // ###############################################

    function _test_SendToken_WhenOperational(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) internal {
        // This interface can be use for both token as we only use balanceOf func
        RLCMock token = RLCMock(tokenAddress);

        // Check initial balances
        uint256 initialBalance = token.balanceOf(user1);
        assertEq(initialBalance, INITIAL_BALANCE, "Initial balance should match expected amount");

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) = TestUtils.prepareSend(
            iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, approvalRequired ? DEST_EID : SOURCE_EID
        );

        // Handle approval if required
        vm.startPrank(user1);
        if (approvalRequired) {
            token.approve(address(iexecLayerZeroBridge), TRANSFER_AMOUNT);
        }

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));
        vm.stopPrank();

        // Verify source state - tokens should be burned/locked
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT, "Tokens should be deducted from sender");
    }

    function _test_Pause_OnlyPauserRole(IexecLayerZeroBridge iexecLayerZeroBridge) internal {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pause();
    }

    function _test_Pause_BlocksOutgoingTransfers(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) public {
        // This interface can be use for both token as we only use balanceOf func
        RLCMock token = RLCMock(tokenAddress);

        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) = TestUtils.prepareSend(
            iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, approvalRequired ? DEST_EID : SOURCE_EID
        );

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(token.balanceOf(user1), INITIAL_BALANCE);
    }

    function _test_Unpause_RestoresFullFunctionality(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) internal {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();

        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Should now work normally
        _test_SendToken_WhenOperational(iexecLayerZeroBridge, tokenAddress, approvalRequired);
    }

    function _test_sendRLCWhenSourceLayerZeroBridgeUnpaused(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) public {
        // This interface can be use for both token as we only use balanceOf func
        RLCMock token = RLCMock(tokenAddress);

        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();
        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) = TestUtils.prepareSend(
            iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, approvalRequired ? DEST_EID : SOURCE_EID
        );

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.startPrank(user1);
        if (approvalRequired) {
            token.approve(address(iexecLayerZeroBridge), TRANSFER_AMOUNT); // For Stargate compatibility, user should approve iexecLayerZeroBridge
        }
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));
        vm.stopPrank();

        // Verify source state - tokens should be burned
        assertEq(token.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    function _test_PauseSend_OnlyPauserRole(IexecLayerZeroBridge iexecLayerZeroBridge) public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pauseSend();
    }

    function _test_PauseSend_BlocksOutgoingOnly(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) public {
        // This interface can be use for both token as we only use balanceOf func
        RLCMock token = RLCMock(tokenAddress);

        // Pause send
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();

        // Verify state
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) = TestUtils.prepareSend(
            iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, approvalRequired ? DEST_EID : SOURCE_EID
        );

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(token.balanceOf(user1), INITIAL_BALANCE);
    }

    function _test_UnpauseSend_RestoresOutgoingTransfers(
        IexecLayerZeroBridge iexecLayerZeroBridge,
        address tokenAddress,
        bool approvalRequired
    ) public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseSend();

        iexecLayerZeroBridge.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.sendPaused());

        _test_SendToken_WhenOperational(iexecLayerZeroBridge, tokenAddress, approvalRequired);
    }

    function _testReturnsApprovalRequired(IexecLayerZeroBridge iexecLayerZeroBridge, bool requireApproval) internal {
        requireApproval ? vm.chainId(1) : vm.chainId(42161);
        assertEq(
            iexecLayerZeroBridge.approvalRequired(),
            requireApproval,
            "approvalRequired() should return the correct value depending on the chain"
        );
    }

    function _testBridgeableTokenAddress(IexecLayerZeroBridge iexecLayerZeroBridge, address tokenAddress)
        internal
        view
    {
        assertEq(iexecLayerZeroBridge.token(), tokenAddress, "token() should return the correct token contract address");
    }
}
