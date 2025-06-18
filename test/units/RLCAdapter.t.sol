// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCMock} from "./mocks/RLCMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {IexecLayerZeroBridge} from "../../src/IexecLayerZeroBridge.sol";
import {TestUtils} from "./utils/TestUtils.sol";

contract RLCAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    RLCAdapter private adapter;
    IexecLayerZeroBridge private layerZeroBridgeMock;
    RLCMock private rlcToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");

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

        // Mint RLC tokens to user1
        rlcToken.transfer(user1, INITIAL_BALANCE);
        vm.prank(user1);
        rlcToken.approve(address(adapter), INITIAL_BALANCE);
    }

    function test_sendToken() public {
        // Check initial balances
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    function test_sendRLCWhenSourceAdapterPaused() public {
        // Pause the destination adapter
        vm.prank(pauser);
        adapter.pause();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(adapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens - this should succeed on source but fail on destination
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        try adapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1)) {
            // If it succeeds, we expect it to revert
            assertTrue(false, "Expected send to revert when source Adapter is paused");
        } catch (bytes memory error) {
            // Expected revert, continue
            assertEq(error, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        }

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_sendRLCWhenSourceAdapterUnpaused() public {
        // Pause then unpause the destination adapter
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
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
