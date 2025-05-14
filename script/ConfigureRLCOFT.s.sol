// script/ConfigureRLCOFT.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract ConfigureRLCOFT is Script {
    function run() external {
        vm.startBroadcast();

        // RLCOFT on Arbitrum Sepolia
        address oftAddress = vm.envAddress("ARBITRUM_SEPOLIA_OFT_ADDRESS");
        RLCOFT oft = RLCOFT(oftAddress);

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("SEPOLIA_ADAPTER_ADDRESS");// Add your RLCAdapter address here
        uint16 ethereumSepoliaChainId = uint16(vm.envUint("SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Ethereum Sepolia

        // Set trusted remote
        oft.setPeer(ethereumSepoliaChainId, bytes32(uint256(uint160(adapterAddress))));

        vm.stopBroadcast();
    }
}
