// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
// import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

contract SendTokensFromEthereumToArbitrum is Script {
    /**
     * @dev Converts an address to bytes32.
     * @param _addr The address to convert.
     * @return The bytes32 representation of the address.
     */
    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    function run() external {
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");

        ConfigLib.CommonConfigParams memory sourceParams = ConfigLib.readCommonConfig(sourceChain);
        ConfigLib.CommonConfigParams memory targetParams = ConfigLib.readCommonConfig(targetChain);

        // Contract addresses
        address iexecLayerZeroBridgeAddress = sourceParams.iexecLayerZeroBridgeAddress;
        address rlcMainnetTokenAddress = sourceParams.rlcToken;

        // Transfer parameters
        uint16 destinationChainId = uint16(targetParams.lzChainId);
        address recipientAddress = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = 5 * 10 ** 9; //  RLC tokens (adjust the amount as needed)

        vm.startBroadcast();
        // First, approve the adapter to spend your tokens
        IERC20 rlcToken = IERC20(rlcMainnetTokenAddress);
        console.log("Approving IexecLayerZeroBridge contract to spend %s RLC", amount / 10 ** 9);
        rlcToken.approve(iexecLayerZeroBridgeAddress, amount);

        // Then, send tokens cross-chain
        IexecLayerZeroBridge adapter = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);
        console.log("Sending %s RLC to Arbitrum Sepolia", amount / 10 ** 9);
        console.log("Recipient: %s", recipientAddress);

        SendParam memory sendParam = SendParam(
            destinationChainId, // Destination endpoint ID.
            addressToBytes32(recipientAddress), // Recipient address.
            amount, // Amount to send in local decimals.
            amount * 99 / 100, // Minimum amount to send in local decimals (allowing 1% slippage).
            "", // Extra options, not used in this case, already setup using `setEnforcedOptions`
            "", // Composed message for the send() operation, unused in this context.
            "" // OFT command to be executed, unused in default OFT implementations.
        );

        MessagingFee memory fee = adapter.quoteSend(sendParam, false);

        console.log("Fee amount: ", fee.nativeFee);

        adapter.send{value: fee.nativeFee}(sendParam, fee, msg.sender);

        console.log("Cross-chain transfer initiated!");
        vm.stopBroadcast();
    }
}
