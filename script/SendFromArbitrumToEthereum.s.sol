// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

contract SendTokensFromArbitrumToEthereum is Script {
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

        // Transfer parameters
        uint16 destinationChainId = uint16(targetParams.lzChainId); // LayerZero chain ID for Ethereum Sepolia
        address recipientAddress = vm.envAddress("RECIPIENT_ADDRESS");
        console.log("Recipient: %s", recipientAddress);

        uint256 amount = 5 * 10 ** 9; // RLC tokens (adjust the amount as needed)

        // Send tokens cross-chain
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);
        console.log("Sending %s RLC to Ethereum Sepolia", amount / 10 ** 9);

        SendParam memory sendParam = SendParam(
            destinationChainId, // Destination endpoint ID.
            addressToBytes32(recipientAddress), // Recipient address.
            amount, // amount (in local decimals, e.g., 5 RLC = 5 * 10 ** 9)
            amount * 99 / 100, // minAmount (allowing 1% slippage)
            "", // Extra options, not used in this case, already setup using `setEnforcedOptions`
            "", // Composed message, not used in this case
            "" // OFT command to be executed, unused in default OFT implementations.
        );

        // Get the fee for the transfer
        MessagingFee memory fee = iexecLayerZeroBridge.quoteSend(sendParam, false);
        console.log("Fee amount: ", fee.nativeFee);

        // Execute the cross-chain transfer
        iexecLayerZeroBridge.send{value: fee.nativeFee}(sendParam, fee, msg.sender);

        console.log("Cross-chain transfer from Arbitrum to Ethereum initiated!");
        vm.stopBroadcast();
    }
}
