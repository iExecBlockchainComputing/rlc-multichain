// script/ConfigureRLCOFT.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract ConfigureRLCOFT is Script {
    function run() external {
        vm.startBroadcast();
        
        // RLCOFT on Arbitrum Sepolia
        // address oftAddress = vm.envAddress("OFT_ADDRESS"); // Add your RLCOFT address here
        address oftAddress = 0x435e2293653a3E80C93290803Faa0d152181B835; // Add your RLCOFT address here
        console.log("oftAddress", oftAddress);

        RLCOFT oft = RLCOFT(oftAddress);
        
        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = 0x2F8b13A6882e4c4ea52d6588510fB7DFbD09E4E5; // Add your RLCAdapter address here
        // address adapterAddress = vm.envAddress("ADAPTER_ADDRESS"); // Add your RLCOFT address here

        uint16 ethereumSepoliaChainId = 40161; // LayerZero chain ID for Ethereum Sepolia
        
        // Set trusted remote
        oft.setPeer(
            ethereumSepoliaChainId,
            bytes32(uint256(uint160(adapterAddress)))
        );
        
        vm.stopBroadcast();
    }
}
