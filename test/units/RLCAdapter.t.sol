// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCOFTMock} from "./mocks/RLCOFTMock.sol";
import {RLCMock} from "./mocks/RLCMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {TestUtils} from "./utils/TestUtils.sol";

contract RLCAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;
    using TestUtils for *;

    RLCAdapter private sourceAdapter;
    RLCOFTMock private destOFTMock;
    RLCMock private rlcToken;

    uint32 private constant SOURCE_EID = 1;
    uint32 private constant DEST_EID = 2;

    address private owner = makeAddr("owner");
    address private pauser = makeAddr("pauser");
    address private user1 = makeAddr("user1");
    address private user2 = makeAddr("user2");

    uint256 private constant INITIAL_BALANCE = 100 ether;
    uint256 private constant TRANSFER_AMOUNT = 1 ether;
    string private name = "RLC OFT Token";
    string private symbol = "RLC";

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Set up endpoints for the deployment
        address lzEndpoint = address(endpoints[SOURCE_EID]);
        address lzEndpointOFT = address(endpoints[DEST_EID]);

        (sourceAdapter, destOFTMock, rlcToken) =
            TestUtils.setupDeployment(name, symbol, lzEndpoint, lzEndpointOFT, owner, pauser);

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(sourceAdapter);
        contracts[1] = address(destOFTMock);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint OFT tokens to user1
        rlcToken.mint(user1, INITIAL_BALANCE);
        vm.prank(user1);
        rlcToken.approve(address(sourceAdapter), INITIAL_BALANCE);
    }

    function test_sendToken() public {
        // Check initial balances
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(sourceAdapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        sourceAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    function test_sendOFTWhenSourceAdapterPaused() public {
        // Pause the destination adapter
        vm.prank(pauser);
        sourceAdapter.pause();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(sourceAdapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens - this should succeed on source but fail on destination
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        try sourceAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1)) {
            // If it succeeds, we expect it to revert
            assertTrue(false, "Expected send to revert when source OFT is paused");
        } catch (bytes memory error) {
            // Expected revert, continue
            assertEq(error, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        }

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE);
    }

    function test_sendOFTWhenSourceAdapterUnpaused() public {
        // Pause then unpause the destination adapter
        vm.startPrank(pauser);
        sourceAdapter.pause();
        sourceAdapter.unpause();
        vm.stopPrank();

        // Prepare send parameters using utility
        (SendParam memory sendParam, MessagingFee memory fee) =
            TestUtils.prepareSend(sourceAdapter, addressToBytes32(user2), TRANSFER_AMOUNT, DEST_EID);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        sourceAdapter.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify source state - tokens should be locked in adapter
        assertEq(rlcToken.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
