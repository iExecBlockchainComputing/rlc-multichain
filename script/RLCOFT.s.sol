// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract DeployRLCOFT is Script {
    RLCOFT public rlcOFT;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        string memory name = vm.envString("TOKEN_NAME");
        string memory symbol = vm.envString("TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address delegate = vm.envAddress("DELEGATE_ADDRESS");
        
        rlcOFT = new RLCOFT(name, symbol, lzEndpoint, delegate);
        console.log("rlcAOFT deployed at:", address(rlcOFT));

        vm.stopBroadcast();
    }
}
