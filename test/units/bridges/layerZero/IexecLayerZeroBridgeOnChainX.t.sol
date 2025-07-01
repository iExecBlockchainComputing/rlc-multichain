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

/**
 * Test Script for the IexecLayerZeroBridge on any chain except Ethereum Mainnet.
 * In this case, IexecLayerZeroBridge should be connected to
 * RLCCrosschainToken deployed on the same chain.
 */
contract IexecLayerZeroBridgeOnChainXTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridgeEthereum;
    IexecLayerZeroBridge private iexecLayerZeroBridgeChainX;
    RLCCrosschainToken private rlcCrosschainToken;

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

        (iexecLayerZeroBridgeEthereum, iexecLayerZeroBridgeChainX,, rlcCrosschainToken,) =
            TestUtils.setupDeployment(name, symbol, lzEndpointDestination, lzEndpointSource, admin, upgrader, pauser);

        address iexecLayerZeroBridgeEthereumAddress = address(iexecLayerZeroBridgeEthereum);
        address iexecLayerZeroBridgeChainXAddress = address(iexecLayerZeroBridgeChainX);
        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = iexecLayerZeroBridgeChainXAddress;
        contracts[1] = iexecLayerZeroBridgeEthereumAddress;
        vm.startPrank(admin);
        wireOApps(contracts);
        vm.stopPrank();

        // Authorize the bridge to mint/burn tokens.
        vm.startPrank(admin);
        rlcCrosschainToken.grantRole(rlcCrosschainToken.TOKEN_BRIDGE_ROLE(), iexecLayerZeroBridgeChainXAddress);
        vm.stopPrank();

        // Mint RLC tokens to user1
        vm.prank(iexecLayerZeroBridgeChainXAddress);
        rlcCrosschainToken.crosschainMint(user1, INITIAL_BALANCE);
    }

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============
    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    //TODO: Add more tests for send functionality, in both directions

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeChainX.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

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
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridgeChainX.pause();
        iexecLayerZeroBridgeChainX.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============

    function test_PauseSend_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridgeChainX.pauseSend();
    }

    function test_PauseSend_BlocksOutgoingOnly() public {
        // Pause send
        vm.prank(pauser);
        iexecLayerZeroBridgeChainX.pauseSend();

        // Verify state
        assertFalse(iexecLayerZeroBridgeChainX.paused());
        assertTrue(iexecLayerZeroBridgeChainX.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridgeChainX, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridgeChainX.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridgeChainX.pauseSend();

        iexecLayerZeroBridgeChainX.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridgeChainX.paused());
        assertFalse(iexecLayerZeroBridgeChainX.sendPaused());

        test_SendToken_WhenOperational();
    }

    // ============ token and approvalRequired ============
    function test_ReturnsBridgeableTokenAddress() public view {
        // On ChainX
        address bridgeableToken = iexecLayerZeroBridgeChainX.token();
        assertEq(
            bridgeableToken, address(rlcCrosschainToken), "token() should return the RLCCrosschain contract address"
        );
    }

    function test_ReturnsApprovalRequired() public {
        // Simulate non-mainnet chain ID
        vm.chainId(31337);
        bool requiresApproval = iexecLayerZeroBridgeChainX.approvalRequired();
        assertFalse(requiresApproval, "approvalRequired() should return false on non-mainnet chains");
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
