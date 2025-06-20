// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";
import {RLCAdapter} from "../../../../src/bridges/layerZero/RLCAdapter.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/common/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";

contract RLCAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    RLCAdapter private adapter;
    IexecLayerZeroBridge private layerZeroBridgeMock;
    RLCMock private rlcToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
    string private name = "RLC Token";
    string private symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointAdapter = address(endpoints[SOURCE_EID]);
        address lzEndpointBridge = address(endpoints[DEST_EID]);

        (adapter, layerZeroBridgeMock, rlcToken,) =
            TestUtils.setupDeployment(name, symbol, lzEndpointAdapter, lzEndpointBridge, owner, pauser);

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(adapter);
        contracts[1] = address(layerZeroBridgeMock);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint RLC tokens to user1 and setup approval
        rlcToken.transfer(user1, INITIAL_BALANCE);
        vm.prank(user1);
        rlcToken.approve(address(adapter), INITIAL_BALANCE);
    }

    // ============ BASIC ADAPTER FUNCTIONALITY TESTS ============

    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter (not burned)
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(adapter)), TRANSFER_AMOUNT);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============

    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        adapter.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the adapter
        vm.prank(pauser);
        adapter.pause();

        // Verify adapter is fully paused
        assertTrue(adapter.paused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were locked
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the adapter
        vm.startPrank(pauser);
        adapter.pause();
        assertTrue(adapter.paused());

        adapter.unpause();
        vm.stopPrank();

        // Should now work normally
        assertFalse(adapter.paused());
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceAdapterUnpaused() public {
        // Pause then unpause the adapter
        vm.startPrank(pauser);
        adapter.pause();
        adapter.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(adapter)), TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============
    function test_PauseSend_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        adapter.pauseSend();
    }

    function test_PauseSend_BlocksOutgoingOnly() public {
        // Pause send
        vm.prank(pauser);
        adapter.pauseSend();

        // Verify state
        assertFalse(adapter.paused());
        assertTrue(adapter.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were locked
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(address(adapter)), 0);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        adapter.pauseSend();
        assertTrue(adapter.sendPaused());

        adapter.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(adapter.paused());
        assertFalse(adapter.sendPaused());

        test_SendToken_WhenOperational();
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
