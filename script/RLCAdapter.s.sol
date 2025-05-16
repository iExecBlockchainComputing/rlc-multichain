// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract DeployRLCAdapter is Script {
    RLCAdapter public rlcAdapter;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address delegate = vm.envAddress("DELEGATE_ADDRESS"); // Your actual wallet address

        rlcAdapter = new RLCAdapter(rlcToken, lzEndpoint, delegate);
        console.log("RLCAdapter deployed at:", address(rlcAdapter));

        vm.stopBroadcast();
        
        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_ADDRESS", address(rlcAdapter));
    }
}
