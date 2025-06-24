// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendParam} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
// import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";

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

        // Contract addresses
        address iexecLayerZeroBridgeAddress = vm.envAddress("LAYERZERO_BRIDGE_ADAPTER_PROXY_ADDRESS"); // Your IexecLayerZeroBridge address
        address liquidityUnifierAddress = vm.envAddress("RLC_LIQUIDITY_UNIFIER_PROXY_ADDRESS"); // Your RLCLiquidityUnifier address
        address rlcTokenAddress = vm.envAddress("RLC_ADDRESS"); // RLC token address on sepolia testnet

        // Transfer parameters
        uint16 destinationChainId = uint16(vm.envUint("LAYER_ZERO_ARBITRUM_SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Arbitrum Sepolia
        address recipientAddress = vm.envAddress("OWNER_ADDRESS"); // Recipient on Arbitrum (your address)
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
