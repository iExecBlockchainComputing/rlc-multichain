// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {RLCLiquidityUnifier} from "../src/RLCLiquidityUnifier.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./lib/UpdateEnvUtils.sol";
import {UpgradeUtils} from "./lib/UpgradeUtils.sol";

/**
 * Deployment script for the RLCLiquidityUnifier contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */
contract Deploy is Script {
    using stdJson for string;

    /**
     * Reads configuration from a JSON file and deploys RLCLiquidityUnifier contract.
     *
     * @return address of the deployed RLCLiquidityUnifier proxy contract.
     */
    function run() external returns (address) {
        // TODO put inside a shared utility function.
        string memory config = vm.readFile("config/config.json");
        address initialAdmin = config.readAddress(".initialAdmin");
        address initialUpgrader = config.readAddress(".initialUpgrader");
        address createxFactory = config.readAddress(".createxFactory");
        string memory chain = vm.envString("CHAIN"); // the same name as the config file.
        string memory prefix = string.concat(".chains.", chain);
        address rlcToken = config.readAddress(string.concat(prefix, ".rlcAddress"));
        bytes32 createxSalt = config.readBytes32(string.concat(prefix, ".rlcLiquidityUnifierCreatexSalt"));
        vm.startBroadcast();
        address liquidityUnifierProxy = deploy(rlcToken, initialAdmin, initialUpgrader, createxFactory, createxSalt);
        vm.stopBroadcast();

        //TODO: use config file to store addresses.
        EnvUtils.updateEnvVariable("RLC_LIQUIDITY_UNIFIER_PROXY_ADDRESS", liquidityUnifierProxy);
        return liquidityUnifierProxy;
    }

    /**
     * Deploys the RLCLiquidityUnifier proxy using CreateX.
     *
     * @param rlcToken The address of the RLC token contract.
     * @param initialAdmin The address of the admin.
     * @param initialUpgrader The address with upgrade permissions.
     * @param createxFactory The CreateX factory address.
     * @param createxSalt The salt for CreateX deployment.
     * @return address of the deployed RLCLiquidityUnifier proxy contract.
     */
    function deploy(
        address rlcToken,
        address initialAdmin,
        address initialUpgrader,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory constructorData = abi.encode(rlcToken);
        bytes memory initData =
            abi.encodeWithSelector(RLCLiquidityUnifier.initialize.selector, initialAdmin, initialUpgrader);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCLiquidityUnifier", constructorData, initData, createxFactory, createxSalt
        );
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = vm.envAddress("RLC_LIQUIDITY_UNIFIER_PROXY_ADDRESS");
        address rlcToken = vm.envAddress("RLC_ADDRESS");

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            constructorData: abi.encode(rlcToken),
            contractName: "RLCLiquidityUnifierV2Mock.sol:RLCLiquidityUnifierV2", // Would be production contract in real deployment
            newStateVariable: 1000000 * 10 ** 9,
            validateOnly: false
        });

        address newImplementationAddress = UpgradeUtils.executeUpgrade(params);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_LIQUIDITY_UNIFIER_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {
        address rlcToken = vm.envAddress("RLC_ADDRESS");
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0),
            constructorData: abi.encode(rlcToken),
            contractName: "RLCLiquidityUnifierV2Mock.sol:RLCLiquidityUnifierV2",
            newStateVariable: 1000000 * 10 ** 9,
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
