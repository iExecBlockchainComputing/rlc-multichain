// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    RLCOFT public rlcOFT;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        string memory name = vm.envString("RLC_OFT_TOKEN_NAME");
        string memory symbol = vm.envString("RLC_TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address delegate = vm.envAddress("DELEGATE_ADDRESS");
        
        rlcOFT = new RLCOFT(name, symbol, lzEndpoint, delegate);
        console.log("rlcOFT deployed at:", address(rlcOFT));

        vm.stopBroadcast();
        
        EnvUtils.updateEnvVariable("ARBITRUM_SEPOLIA_RLC_OFT_ADDRESS", address(rlcOFT));
    }
}
