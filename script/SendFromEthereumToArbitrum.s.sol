// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

/**
 * Script to send tokens from Ethereum Mainnet/Testnet to Arbitrum Mainnet/Testnet.
 * This script demonstrates cross-chain token transfers using LayerZero bridge.
 */
contract SendFromEthereumToArbitrum is Script {
    uint256 private constant TRANSFER_AMOUNT = 1 * 10 ** 9; // 1 RLC token with 9 decimals
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

        IexecLayerZeroBridge sourceBridge = IexecLayerZeroBridge(sourceParams.iexecLayerZeroBridgeAddress);
        IERC20 rlcToken = IERC20(sourceParams.rlcToken);

        address sender = vm.envAddress("RECIPIENT_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");

        // Check sender's balance
        uint256 senderBalance = rlcToken.balanceOf(sender);
        require(senderBalance >= TRANSFER_AMOUNT, "Insufficient RLC balance");

        // Prepare send parameters
        SendParam memory sendParam = SendParam(
            uint16(targetParams.lzEndpointId), // Destination endpoint ID
            addressToBytes32(recipient), // Recipient address
            TRANSFER_AMOUNT, // Amount to send in local decimals
            TRANSFER_AMOUNT * 99 / 100, // Minimum amount to send (allowing 1% slippage)
            "", // Extra options, already set via setEnforcedOptions
            "", // Composed message for send() operation (unused)
            "" // OFT command to be executed (unused in default OFT)
        );

        // Get quote for the transfer
        MessagingFee memory fee = sourceBridge.quoteSend(sendParam, false);

        console.log("=== Cross-Chain Transfer Details ===");
        console.log("From: Ethereum Mainnet");
        console.log("To: Arbitrum Mainnet");
        console.log("Amount: %d RLC", TRANSFER_AMOUNT / 10 ** 9);
        console.log("Fee: %d wei", fee.nativeFee);
        console.log("Sender: %s", sender);
        console.log("Recipient: %s", recipient);
        console.log("Sender Balance: %d RLC", senderBalance / 10 ** 9);

        vm.startBroadcast();

        // Approve bridge to spend tokens if needed
        uint256 currentAllowance = rlcToken.allowance(sender, address(sourceBridge));
        if (currentAllowance < TRANSFER_AMOUNT) {
            console.log("Approving bridge to spend %d RLC", TRANSFER_AMOUNT / 10 ** 9);
            rlcToken.approve(address(sourceBridge), TRANSFER_AMOUNT);
        }

        // Execute cross-chain transfer
        console.log("Initiating cross-chain transfer...");
        sourceBridge.send{value: fee.nativeFee}(sendParam, fee, payable(sender));

        vm.stopBroadcast();

        console.log("Transfer initiated successfully!");
        console.log("Monitor the destination chain for token receipt.");
    }
}
