// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
// import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";



contract SendEthereumToArbitrum is Script {

    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() external {
        vm.startBroadcast();
        
        // Contract addresses
        address adapterAddress = 0x2F8b13A6882e4c4ea52d6588510fB7DFbD09E4E5; // Your RLCAdapter address
        address rlcTokenAddress = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd; // RLC token on Sepolia
        
        // Transfer parameters
        uint16 destinationChainId = 40231; // Arbitrum Sepolia
        address recipientAddress = 0x316A389d7f0Ac46B19FCbE7076f125566f09CEBc; // Recipient on Arbitrum (your address)
        uint256 amount = 10000 * 10**9; //  RLC tokens (adjust the amount as needed)
        address refundAddress = 0x316A389d7f0Ac46B19FCbE7076f125566f09CEBc; // Your address for refunds
        address zroPaymentAddress = address(0); // Usually zero address
        
        // First, approve the adapter to spend your tokens
        IERC20 rlcToken = IERC20(rlcTokenAddress);
        console.log("Approving RLCAdapter to spend %s RLC", amount / 10**9);
        rlcToken.approve(adapterAddress, amount);
        
        // Then, send tokens cross-chain
        RLCAdapter adapter = RLCAdapter(adapterAddress);
        console.log("Sending %s RLC to Arbitrum Sepolia", amount / 10**9);
        console.log("Recipient: %s", recipientAddress);

        // bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        bytes memory _extraOptions = abi.encodePacked(
            uint16(3),
            uint8(1),
            uint16(33),
            uint8(1),
            uint128(65000),
            uint128(0)
        );
        SendParam memory sendParam = SendParam(
            40231, // You can also make this dynamic if needed
            addressToBytes32(recipientAddress),
            amount,
            amount * 9 / 10,
            _extraOptions,
            "",
            ""
        );

        MessagingFee memory fee = adapter.quoteSend(sendParam, false);

        console.log("Fee amount: ", fee.nativeFee);

        adapter.send{value: fee.nativeFee}(sendParam, fee, msg.sender);
        
        console.log("Cross-chain transfer initiated!");
        vm.stopBroadcast();
    }
}
