// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {MessagingFee, SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Deploy as RLCOFTDeploy} from "../../script/RLCOFT.s.sol";
import {RLCMock} from "../units/mocks/RLCMock.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";

contract RLCOFTest is Test {

    RLCOFT internal rlcOft;
    RLCMock internal rlcTokenMock;
    address internal adapterAddress = makeAddr("adapter");
    address public lzEndpoint = makeAddr("endpoint");

    address public owner = makeAddr("owner");
    address public bridge = makeAddr("bridge");
    address public pauser = makeAddr("pauser");
    address public sender = makeAddr("sender");
    address public receiver = makeAddr("receiver");
    address public refundAddress = makeAddr("refundAddress");

    SendParam internal sendParam;
    MessagingFee internal fee;

    function setUp() public {
        // Deploy RLC token mock
        rlcTokenMock = new RLCMock("RLC OFT Test", "RLCT");
        // Deploy OFT contract
        rlcOft = RLCOFT(new RLCOFTDeploy().runWithParams(
            "RLC OFT Token",
            "RLCOFT",
            lzEndpoint,
            owner,
            pauser
        ));
        // Authorize peer.
        rlcOft.setPeer(
            uint16(111), // random destination id
            addressToBytes32(address(adapterAddress))
        );
        sendParam = SendParam({
            dstEid: 1,
            to: addressToBytes32(receiver),
            amountLD: 1000,
            minAmountLD: 1000,
            extraOptions: "",
            composeMsg: "",
            oftCmd: ""
        });
        // fee = rlcOft.quoteSend(sendParam, false);
        fee = MessagingFee({
            nativeFee: 0,
            lzTokenFee: 0
        });
    }

    function test_RevertWhenSendingInPausePeriod() public {
        // Pause contract.
        vm.prank(pauser);
        rlcOft.pause();
        // Try to send tokens while paused.
        vm.startPrank(sender);
        vm.expectRevert();
        rlcOft.send(
            sendParam,
            fee,
            refundAddress
        );
        // TODO assert balances.
    }

    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }
}
