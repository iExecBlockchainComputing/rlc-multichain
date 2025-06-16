// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {RLCCrosschainToken} from "../src/token/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";

/**
 * Deployment script for the RLCCrosschainToken contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */
contract Deploy is Script {
    using stdJson for string;

    /**
     * Reads configuration from a JSON file and deploys RLCCrosschainToken contract.
     *
     * @return address of the deployed RLCCrosschainToken proxy contract.
     */
    function run() external returns (address) {
        // TODO put inside a shared utility function.
        string memory config = vm.readFile("config/config.json");
        address owner = config.readAddress(".owner");
        address upgrader = config.readAddress(".upgrader");
        address createxFactory = config.readAddress(".createxFactory");
        string memory chain = vm.envString("CHAIN"); // the same name as the config file.
        string memory prefix = string.concat(".chains.", chain);
        bytes32 createxSalt = config.readBytes32(string.concat(prefix, ".rlcCrossChainTokenCreatexSalt"));
        vm.startBroadcast();
        address rlcCrosschainTokenProxy = deploy("RLC Crosschain Token", "RLC", owner, upgrader, createxFactory, createxSalt);
        vm.stopBroadcast();
        // TODO save contract address.
        return rlcCrosschainTokenProxy;
    }

    /**
     * Deploys the RLCCrosschainToken proxy using CreateX.
     *
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param owner The address of the owner.
     * @param upgrader The address with upgrade permissions.
     * @param createxFactory The CreateX factory address.
     * @param createxSalt The salt for CreateX deployment.
     * @return address of the deployed RLCCrosschainToken proxy contract.
     */
    function deploy(
        string memory name,
        string memory symbol,
        address owner,
        address upgrader,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory initData =
            abi.encodeWithSelector(RLCCrosschainToken.initialize.selector, name, symbol, owner, upgrader);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCCrosschainToken", "", initData, createxFactory, createxSalt
        );
    }
}
