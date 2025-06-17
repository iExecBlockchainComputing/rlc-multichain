// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";

contract SendTokensToSepolia is Script {
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
        address iexecLayerZeroBridgeAddress = vm.envAddress("LAYERZERO_BRIDGE_PROXY_ADDRESS");

        // Transfer parameters
        uint16 destinationChainId = uint16(vm.envUint("LAYER_ZERO_SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Ethereum Sepolia
        address recipientAddress = vm.envAddress("OWNER_ADDRESS"); // Recipient on Ethereum Sepolia
        console.log("Recipient: %s", recipientAddress);

        uint256 amount = 5 * 10 ** 18; // RLC tokens (adjust the amount as needed)

        // Send tokens cross-chain
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);
        console.log("Sending %s RLC to Ethereum Sepolia", amount / 10 ** 9);

        // Estimate gas for the OFT endpoint
        // TODO extract in function and document
        bytes memory _extraOptions =
            abi.encodePacked(uint16(3), uint8(1), uint16(33), uint8(1), uint128(65000), uint128(0));

        SendParam memory sendParam = SendParam(
            destinationChainId,
            addressToBytes32(recipientAddress),
            amount,
            amount * 9 / 10, // minAmount (allowing 10% slippage)
            _extraOptions,
            "",
            ""
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
