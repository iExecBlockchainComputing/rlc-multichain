// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./lib/UpdateEnvUtils.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

/**
 * Deployment script for the RLCCrosschainToken contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */
contract Deploy is Script {
    /**
     * Reads configuration from a JSON file and deploys RLCCrosschainToken contract.
     * @return address of the deployed RLCCrosschainToken proxy contract.
     */
    function run() external returns (address) {
        // TODO put inside a shared utility function.
        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(config, chain);
        vm.startBroadcast();
        address rlcCrosschainTokenProxy = deploy(
            "iEx.ec Network Token",
            "RLC",
            params.initialAdmin,
            params.initialUpgrader,
            params.createxFactory,
            params.createxSalt
        );
        vm.stopBroadcast();

        //TODO: use config file to store addresses.
        EnvUtils.updateEnvVariable("RLC_CROSSCHAIN_ADDRESS", rlcCrosschainTokenProxy);
        return rlcCrosschainTokenProxy;
    }

    /**
     * Deploys the RLCCrosschainToken proxy using CreateX.
     *
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialAdmin The address of the admin.
     * @param initialUpgrader The address with upgrade permissions.
     * @param createxFactory The CreateX factory address.
     * @param createxSalt The salt for CreateX deployment.
     * @return address of the deployed RLCCrosschainToken proxy contract.
     */
    function deploy(
        string memory name,
        string memory symbol,
        address initialAdmin,
        address initialUpgrader,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory initData =
            abi.encodeWithSelector(RLCCrosschainToken.initialize.selector, name, symbol, initialAdmin, initialUpgrader);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCCrosschainToken", "", initData, createxFactory, createxSalt
        );
    }
}
