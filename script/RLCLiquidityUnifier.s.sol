// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {RLCLiquidityUnifier} from "../src/RLCLiquidityUnifier.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./lib/UpdateEnvUtils.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {UpgradeUtils} from "./lib/UpgradeUtils.sol";
/**
 * Deployment script for the RLCLiquidityUnifier contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */

contract Deploy is Script {
    /**
     * Reads configuration from config file and deploys RLCLiquidityUnifier contract.
     * @return address of the deployed RLCLiquidityUnifier proxy contract.
     */
    function run() external returns (address) {
        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(config, chain);

        vm.startBroadcast();
        address liquidityUnifierProxy = deploy(
            params.rlcToken, params.initialAdmin, params.initialUpgrader, params.createxFactory, params.createxLUSalt
        );
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

        UpgradeUtils.executeUpgrade(params);
        vm.stopBroadcast();
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
