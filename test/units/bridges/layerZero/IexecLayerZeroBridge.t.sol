// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {CreateX} from "@createx/contracts/CreateX.sol";
import {RLCMock} from "../../mocks/RLCMock.sol";
import {RLCAdapter} from "../../../../src/bridges/layerZero/RLCAdapter.sol";
import {IexecLayerZeroBridge} from "../../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {DualPausableUpgradeable} from "../../../../src/bridges/common/DualPausableUpgradeable.sol";
import {TestUtils} from "../../utils/TestUtils.sol";

contract IexecLayerZeroBridgeTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    // ============ STATE VARIABLES ============
    IexecLayerZeroBridge private iexecLayerZeroBridge;
    RLCAdapter private adapterMock;
    RLCMock private rlcCrosschainToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");
    address private unauthorizedUser = makeAddr("unauthorizedUser");

    uint256 private constant INITIAL_BALANCE = 100 * 10 ** 9; // 100 RLC tokens with 9 decimals
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
    string private name = "RLC Crosschain Token";
    string private symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpointBridge = address(endpoints[SOURCE_EID]);
        address lzEndpointAdapter = address(endpoints[DEST_EID]);

        (adapterMock, iexecLayerZeroBridge,, rlcCrosschainToken) =
            TestUtils.setupDeployment(name, symbol, lzEndpointAdapter, lzEndpointBridge, owner, pauser);

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(iexecLayerZeroBridge);
        contracts[1] = address(adapterMock);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint RLC tokens to user1
        rlcCrosschainToken.crosschainMint(user1, INITIAL_BALANCE);
    }

    // ============ BASIC BRIDGE FUNCTIONALITY TESTS ============

    function test_SendToken_WhenOperational() public {
        // Check initial balances
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 1 PAUSE TESTS (Complete Pause) ============
    function test_Pause_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pause();
    }

    function test_Pause_BlocksOutgoingTransfers() public {
        // Pause the bridge
        vm.prank(pauser);
        iexecLayerZeroBridge.pause();

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_Unpause_RestoresFullFunctionality() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();

        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Should now work normally
        test_SendToken_WhenOperational();
    }

    function test_sendRLCWhenSourceLayerZeroBridgeUnpaused() public {
        // Pause then unpause the bridge
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pause();
        iexecLayerZeroBridge.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    // ============ LEVEL 2 PAUSE TESTS (Send Pause) ============

    function test_PauseSend_OnlyPauserRole() public {
        vm.expectRevert();
        vm.prank(unauthorizedUser);
        iexecLayerZeroBridge.pauseSend();
    }

    function test_PauseSend_BlocksOutgoingOnly() public {
        // Pause send
        vm.prank(pauser);
        iexecLayerZeroBridge.pauseSend();

        // Verify state
        assertFalse(iexecLayerZeroBridge.paused());
        assertTrue(iexecLayerZeroBridge.sendPaused());

        // Prepare send parameters
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(iexecLayerZeroBridge, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Attempt to send tokens - should revert with EnforcedSendPause
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        vm.expectRevert(DualPausableUpgradeable.EnforcedSendPause.selector);
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify no tokens were burned
        assertEq(rlcCrosschainToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_UnpauseSend_RestoresOutgoingTransfers() public {
        // Pause then unpause send
        vm.startPrank(pauser);
        iexecLayerZeroBridge.pauseSend();

        iexecLayerZeroBridge.unpauseSend();
        vm.stopPrank();

        // Should now work normally
        assertFalse(iexecLayerZeroBridge.paused());
        assertFalse(iexecLayerZeroBridge.sendPaused());

        test_SendToken_WhenOperational();
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
