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

contract SendTokensToArbitrumSepolia is Script {
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
        address liquidityUnifierAddress = sourceParams.rlcLiquidityUnifier;
        address rlcTokenAddress = sourceParams.rlcToken;

        // Transfer parameters
        uint16 destinationChainId = uint16(targetParams.lzChainId);
        address recipientAddress = targetParams.initialAdmin; // Replace with the actual recipient address
        uint256 amount = 5 * 10 ** 9; //  RLC tokens (adjust the amount as needed)

        // First, approve the adapter to spend your tokens
        IERC20 rlcToken = IERC20(rlcTokenAddress);
        console.log("Approving RLCLiquidityUnifier contract to spend %s RLC", amount / 10 ** 9);
        rlcToken.approve(liquidityUnifierAddress, amount);

        // Then, send tokens cross-chain
        IexecLayerZeroBridge adapter = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);
        console.log("Sending %s RLC to Arbitrum Sepolia", amount / 10 ** 9);
        console.log("Recipient: %s", recipientAddress);

        // bytes memory _extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(65000, 0);
        bytes memory _extraOptions =
            abi.encodePacked(uint16(3), uint8(1), uint16(33), uint8(1), uint128(65000), uint128(0));
        SendParam memory sendParam = SendParam(
            destinationChainId, // You can also make this dynamic if needed
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
