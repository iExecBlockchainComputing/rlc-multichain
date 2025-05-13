// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";

contract DeployRLCOFT is Script {
    RLCOFT public rlcOFT;

    function setUp() public {}

    function run() external {
        vm.startBroadcast();

        string memory name = "iEx.ec Network Token";
        string memory symbol = "RLC";
        address lzEndpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        address delegate = 0x316A389d7f0Ac46B19FCbE7076f125566f09CEBc; // Your actual wallet address
        console.log("Delegate/owner address:", delegate);
        rlcOFT = new RLCOFT(name, symbol, lzEndpoint, delegate);
        console.log("rlcAOFT deployed at:", address(rlcOFT));

        vm.stopBroadcast();
    }
}
