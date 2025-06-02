// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {RLCOFTMock, Deploy as RLCOFTDeploy} from "../units/mocks/RLCOFTMock.sol";
import {Deploy as RLCAdapterDeploy} from "../units/mocks/RLCAdapterMock.sol";
import {RLCMock} from "../units/mocks/RLCMock.sol";
import {RLCAdapter} from "../../src/RLCAdapter.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTE2ETest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    RLCOFTMock internal sourceOFT;
    RLCAdapter internal destAdapter;
    RLCMock internal rlcToken;

    uint32 internal constant SOURCE_EID = 1;
    uint32 internal constant DEST_EID = 2;

    address public owner = makeAddr("owner");
    address public pauser = makeAddr("pauser");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant TRANSFER_AMOUNT = 1 ether;

    function setUp() public virtual override {
        super.setUp();
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Deploy RLC token mock
        rlcToken = new RLCMock("RLC OFT Test", "RLCT");

        // Set up endpoints for the deployment
        address lzEndpointOFT = address(endpoints[SOURCE_EID]);
        address lzEndpointAdapter = address(endpoints[DEST_EID]);

        // Deploy source RLCOFT
        sourceOFT = RLCOFTMock(new RLCOFTDeploy().run(lzEndpointOFT, owner, pauser));

        // Deploy destination RLCAdapter
        destAdapter = RLCAdapter(new RLCAdapterDeploy().run(address(rlcToken), lzEndpointAdapter, owner, pauser));

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(sourceOFT);
        contracts[1] = address(destAdapter);
        vm.startPrank(owner);
        wireOApps(contracts);
        vm.stopPrank();

        // Mint OFT tokens to user1
        sourceOFT.mint(user1, INITIAL_BALANCE);

        // Mint underlying RLC tokens to destination adapter for withdrawal
        rlcToken.mint(address(destAdapter), INITIAL_BALANCE);
    }

    function test_sendToken() public {
        // Check initial balances
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(user2), 0);

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: DEST_EID,
            to: addressToBytes32(user2),
            amountLD: TRANSFER_AMOUNT,
            minAmountLD: TRANSFER_AMOUNT,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Get quote for the transfer
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // Perform the cross-chain transfer
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify packets - this should succeed
        this.verifyPackets(DEST_EID, addressToBytes32(address(destAdapter)));

        // Verify source state - tokens should be locked in adapter
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);

        // Verify destination state - tokens should be minted to user2
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(user2), TRANSFER_AMOUNT);
    }

    function test_sendOFTWhenSourceOFTPaused() public {
        // Pause the destination adapter
        vm.prank(pauser);
        sourceOFT.pause();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: DEST_EID,
            to: addressToBytes32(user2),
            amountLD: TRANSFER_AMOUNT,
            minAmountLD: TRANSFER_AMOUNT,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Quote the send fee
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // Send tokens - this should succeed on source but fail on destination
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        try sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1)) {
            // If it succeeds, we expect it to revert
            assertTrue(false, "Expected send to revert when source OFT is paused");
        } catch (bytes memory error) {
            // Expected revert, continue
            assertEq(error, abi.encodeWithSelector(PausableUpgradeable.EnforcedPause.selector));
        }

        // Verify source state - tokens should be locked in adapter
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE);

        // Verify destination state - tokens should be minted to user2
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE);
        assertEq(rlcToken.balanceOf(user2), 0);
    }

    function test_sendOFTWhenSourceOFTUnpaused() public {
        // Pause then unpause the destination adapter
        vm.prank(pauser);
        sourceOFT.pause();
        vm.prank(pauser);
        sourceOFT.unpause();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam = SendParam({
            dstEid: DEST_EID,
            to: addressToBytes32(user2),
            amountLD: TRANSFER_AMOUNT,
            minAmountLD: TRANSFER_AMOUNT,
            extraOptions: options,
            composeMsg: "",
            oftCmd: ""
        });

        // Quote the send fee
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // Send tokens
        vm.deal(user1, fee.nativeFee);
        vm.prank(user1);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify packets - this should succeed
        this.verifyPackets(DEST_EID, addressToBytes32(address(destAdapter)));

        // Verify source state - tokens should be locked in adapter
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);

        // Verify destination state - tokens should be minted to user2
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(user2), TRANSFER_AMOUNT);
    }

    //TODO: Add more tests when destination adapter is paused/unpaused
    //TODO: Add fuzzing to test sharedDecimals and sharedDecimalsRounding issues
}
