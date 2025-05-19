// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();

        string memory name = vm.envString("RLC_OFT_TOKEN_NAME");
        string memory symbol = vm.envString("RLC_TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address delegate = vm.envAddress("SENDER_ADDRESS");

        Options memory options;
        options.constructorData = abi.encode(lzEndpoint);
        address rlcOFTProxy = Upgrades.deployUUPSProxy(
            "RLCAdapter.sol",
            abi.encodeCall(RLCOFT.initialize, (name, symbol, delegate)),
            options
        );
        console.log("rlcOFTProxy deployed at:", rlcOFTProxy);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", rlcOFTProxy);
    }
}
