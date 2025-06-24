// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {LiquidityUnifier} from "../src/LiquidityUnifier.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./lib/UpdateEnvUtils.sol";

/**
 * Deployment script for the LiquidityUnifier contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */
contract Deploy is Script {
    using stdJson for string;

    /**
     * Reads configuration from a JSON file and deploys LiquidityUnifier contract.
     *
     * @return address of the deployed LiquidityUnifier proxy contract.
     */
    function run() external returns (address) {
        // TODO put inside a shared utility function.
        string memory config = vm.readFile("config/config.json");
        address admin = config.readAddress(".admin");
        address upgrader = config.readAddress(".upgrader");
        address createxFactory = config.readAddress(".createxFactory");
        string memory chain = vm.envString("CHAIN"); // the same name as the config file.
        string memory prefix = string.concat(".chains.", chain);
        address rlcToken = config.readAddress(string.concat(prefix, ".rlcAddress"));
        bytes32 createxSalt = config.readBytes32(string.concat(prefix, ".liquidityUnifierCreatexSalt"));
        vm.startBroadcast();
        address liquidityUnifierProxy = deploy(rlcToken, admin, upgrader, createxFactory, createxSalt);
        vm.stopBroadcast();

        //TODO: use config file to store addresses.
        EnvUtils.updateEnvVariable("LIQUIDITY_UNIFIER_PROXY_ADDRESS", liquidityUnifierProxy);
        return liquidityUnifierProxy;
    }

    /**
     * Deploys the LiquidityUnifier proxy using CreateX.
     *
     * @param rlcToken The address of the RLC token contract.
     * @param admin The address of the admin.
     * @param upgrader The address with upgrade permissions.
     * @param createxFactory The CreateX factory address.
     * @param createxSalt The salt for CreateX deployment.
     * @return address of the deployed LiquidityUnifier proxy contract.
     */
    function deploy(address rlcToken, address admin, address upgrader, address createxFactory, bytes32 createxSalt)
        public
        returns (address)
    {
        bytes memory constructorData = abi.encode(rlcToken);
        bytes memory initData = abi.encodeWithSelector(LiquidityUnifier.initialize.selector, admin, upgrader);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "LiquidityUnifier", constructorData, initData, createxFactory, createxSalt
        );
    }
}
