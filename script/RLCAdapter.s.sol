// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";

contract DeployRLCAdapter is Script {
    RLCAdapter public rlcAdapter;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        address rlcToken = 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd; // RLC token address on sepolia testnet
        address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f; // LayerZero sepolia endpoint
        address delegate = 0x316A389d7f0Ac46B19FCbE7076f125566f09CEBc; // Your actual wallet address
        console.log("Delegate/owner address:", delegate);

        rlcAdapter = new RLCAdapter(rlcToken, lzEndpoint, delegate);
        console.log("RLCAdapter deployed at:", address(rlcAdapter));

        vm.stopBroadcast();
    }
}

// 0x607F4C5BB672230e8672085532f7e901544a7375 => mainnet 