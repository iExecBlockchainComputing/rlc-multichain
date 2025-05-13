// script/ConfigureRLCAdapter.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract ConfigureRLCAdapter is Script {
    function run() external {
        vm.startBroadcast();
        
        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = 0x2F8b13A6882e4c4ea52d6588510fB7DFbD09E4E5; // Add your RLCAdapter address here
        // address adapterAddress = vm.envAddress("ADAPTER_ADDRESS"); // Add your RLCOFT address here
        RLCAdapter adapter = RLCAdapter(adapterAddress);
        
        // RLCOFT on Arbitrum Sepolia
        address oftAddress = 0x435e2293653a3E80C93290803Faa0d152181B835; // Add your RLCOFT address here
        // address oftAddress = vm.envAddress("OFT_ADDRESS"); // Add your RLCOFT address here
        uint16 arbitrumSepoliaChainId = 40231; // LayerZero chain ID for Arbitrum Sepolia
        
        // Set trusted remote
        adapter.setPeer(
            arbitrumSepoliaChainId,
            bytes32(uint256(uint160(oftAddress)))
        );
        
        vm.stopBroadcast();
    }
}
