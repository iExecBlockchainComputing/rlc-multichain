// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract DeployRLCAdapter is Script {
    RLCAdapter public rlcAdapter;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address delegate = vm.envAddress("DELEGATE_ADDRESS"); // Your actual wallet address

        rlcAdapter = new RLCAdapter(rlcToken, lzEndpoint, delegate);
        console.log("RLCAdapter deployed at:", address(rlcAdapter));

        vm.stopBroadcast();
    }
}

// 0x607F4C5BB672230e8672085532f7e901544a7375 => mainnet
