// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract SendTokensToSepolia is Script {
    using OptionsBuilder for bytes;

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

        string memory config = vm.readFile("config/config.json");
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");

        ConfigLib.CommonConfigParams memory sourceParams = ConfigLib.readCommonConfig(config, sourceChain);
        ConfigLib.CommonConfigParams memory targetParams = ConfigLib.readCommonConfig(config, targetChain);

        // Contract addresses
        address iexecLayerZeroBridgeAddress = sourceParams.layerZeroBridge;
        address rlcArbitrumTokenAddress = sourceParams.rlcToken;

        // Transfer parameters
        uint16 destinationChainId = uint16(targetParams.layerZeroChainId); // LayerZero chain ID for Ethereum Sepolia
        address recipientAddress = vm.envAddress("RECIPIENT_ADDRESS");
        console.log("Recipient: %s", recipientAddress);

        uint256 amount = 5 * 10 ** 9; // RLC tokens (adjust the amount as needed)

        IERC20 rlcToken = IERC20(rlcArbitrumTokenAddress);
        console.log("Approving RLC token transfer of %s", amount / 10 ** 9);
        rlcToken.approve(iexecLayerZeroBridgeAddress, amount);

        // Send tokens cross-chain
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);
        console.log("Sending %s RLC to Ethereum Sepolia", amount / 10 ** 9);

        // Estimate gas for the OFT endpoint
        bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0); // 65000 gas limit for the receiving executor and 0 for the executor's value

        SendParam memory sendParam = SendParam(
            destinationChainId, // Destination endpoint ID.
            addressToBytes32(recipientAddress), // Recipient address.
            amount, // amount (in local decimals, e.g., 5 RLC = 5 * 10 ** 9)
            amount * 9 / 10, // minAmount (allowing 10% slippage)
            _extraOptions, // Extra options for the LayerZero message
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
