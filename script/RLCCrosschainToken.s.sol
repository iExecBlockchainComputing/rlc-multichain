// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {RLCCrosschainToken} from "../src/token/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";

contract Deploy is Script {
    using stdJson for string;

    function run() external returns (address) {
        vm.startBroadcast();
        // TODO put inside a shared utility function.
        string memory config = vm.readFile("config/config.json");
        address owner = config.readAddress(".owner");
        address upgrader = config.readAddress(".upgrader");
        address createxFactory = config.readAddress(".createxFactory");
        string memory chain = vm.envString("CHAIN"); // e.g. "sepolia" or "arbitrum_sepolia"
        string memory prefix = string.concat(".chains.", chain);
        bytes32 createxSalt = config.readBytes32(string.concat(prefix, ".rlcCrossChainTokenCreatexSalt"));
        address rlcCrosschainTokenProxy = deploy("RLC Token", "RLC", owner, upgrader, createxFactory, createxSalt);
        vm.stopBroadcast();
        // TODO save contract address.
        return rlcCrosschainTokenProxy;
    }

    function deploy(
        string memory name,
        string memory symbol,
        address owner,
        address upgrader,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory initData = abi.encodeWithSelector(
            RLCCrosschainToken.initialize.selector,
            name,
            symbol,
            owner,
            upgrader
        );
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCCrosschainToken", "", initData, createxFactory, createxSalt
        );
    }
}
