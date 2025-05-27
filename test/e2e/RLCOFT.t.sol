// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {MessagingFee, SendParam, OFTReceipt} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import {ERC20Mock} from "@layerzerolabs/oft-evm/test/mocks/ERC20Mock.sol";
import {Deploy as RLCOFTDeploy} from "../../script/RLCOFT.s.sol";
import {Deploy as RLCAdapterDeploy} from "../../script/RLCAdapter.s.sol";

import "../../src/RLCAdapter.sol";
import "../../src/RLCOFT.sol";

contract RLCOFTPauseE2ETest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    uint32 internal constant SOURCE_EID = 1;
    uint32 internal constant DEST_EID = 2;

    RLCOFT internal sourceOFT;
    RLCAdapter internal destAdapter;
    ERC20Mock internal rlcToken;

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
        rlcToken = new ERC20Mock("RLC OFT Test", "RLCT");

        // Set up environment variables for the deployment
        vm.setEnv("RLC_OFT_TOKEN_NAME", "RLC OFT Test");
        vm.setEnv("RLC_TOKEN_SYMBOL", "RLCT");
        vm.setEnv("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS", vm.toString(address(endpoints[SOURCE_EID])));
        vm.setEnv("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS", vm.toString(address(endpoints[DEST_EID])));
        vm.setEnv("OWNER_ADDRESS", vm.toString(owner));
        vm.setEnv("PAUSER_ADDRESS", vm.toString(pauser));

        // Deploy source RLCOFT
        sourceOFT = RLCOFT(new RLCOFTDeploy().run());

        // Deploy destination RLCAdapter
        destAdapter = RLCAdapter(new RLCAdapterDeploy().run());

        // Wire the contracts
        address[] memory contracts = new address[](2);
        contracts[0] = address(sourceOFT);
        contracts[1] = address(destAdapter);
        this.wireOApps(contracts);

        // Mint OFT tokens to user1
        vm.prank(owner);
        sourceOFT.mint(user1, INITIAL_BALANCE);

        // Mint underlying RLC tokens to destination adapter for withdrawal
        rlcToken.mint(address(destAdapter), INITIAL_BALANCE);
    }

    function test_sendOFTWhenDestinationAdapterPaused() public {
        // Pause the destination adapter
        vm.prank(pauser);
        destAdapter.pause();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(DEST_EID, addressToBytes32(user2), TRANSFER_AMOUNT, TRANSFER_AMOUNT, options, "", "");

        // Quote the send fee
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // Send tokens - this should succeed on source but fail on destination
        vm.prank(user1);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify packets - this should trigger the paused revert
        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector);
        this.verifyPackets(DEST_EID, addressToBytes32(address(destAdapter)));

        // Verify source state - OFT tokens should be burned
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);

        // Verify destination state - no RLC tokens should be transferred
        assertEq(rlcToken.balanceOf(user2), 0);
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE);
    }

    function test_sendOFTWhenDestinationAdapterUnpaused() public {
        // Pause then unpause the destination adapter
        vm.prank(pauser);
        destAdapter.pause();
        vm.prank(pauser);
        destAdapter.unpause();

        // Prepare send parameters
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(DEST_EID, addressToBytes32(user2), TRANSFER_AMOUNT, TRANSFER_AMOUNT, options, "", "");

        // Quote the send fee
        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        // Send tokens
        vm.prank(user1);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        // Verify packets - this should succeed
        this.verifyPackets(DEST_EID, addressToBytes32(address(destAdapter)));

        // Verify source state
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);

        // Verify destination state - RLC tokens should be transferred to user2
        assertEq(rlcToken.balanceOf(user2), TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }

    function test_sendOFTNormalOperation() public {
        // Normal operation without pausing
        bytes memory options = OptionsBuilder.newOptions().addExecutorLzReceiveOption(200000, 0);
        SendParam memory sendParam =
            SendParam(DEST_EID, addressToBytes32(user2), TRANSFER_AMOUNT, TRANSFER_AMOUNT, options, "", "");

        MessagingFee memory fee = sourceOFT.quoteSend(sendParam, false);

        vm.prank(user1);
        sourceOFT.send{value: fee.nativeFee}(sendParam, fee, payable(user1));

        this.verifyPackets(DEST_EID, addressToBytes32(address(destAdapter)));

        // Verify final state
        assertEq(sourceOFT.balanceOf(user1), INITIAL_BALANCE - TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(user2), TRANSFER_AMOUNT);
        assertEq(rlcToken.balanceOf(address(destAdapter)), INITIAL_BALANCE - TRANSFER_AMOUNT);
    }
}
