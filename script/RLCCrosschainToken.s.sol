// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

/**
 * Deployment script for the RLCCrosschainToken contract.
 * It reads configuration from a JSON file and deploys the contract using CreateX.
 */
contract Deploy is Script {
    /**
     * Reads configuration from config file and deploys RLCCrosschainToken contract.
     * @return address of the deployed RLCCrosschainToken proxy contract.
     */
    function run() external returns (address) {
        string memory chain = vm.envString("CHAIN");
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        address rlcCrosschainTokenProxy = deploy(
            "iEx.ec Network Token",
            "RLC",
            params.initialAdmin,
            params.initialUpgrader,
            params.createxFactory,
            params.rlcCrosschainTokenCreatexSalt
        );
        vm.stopBroadcast();

        ConfigLib.updateConfigAddress(chain, "rlcCrosschainTokenAddress", rlcCrosschainTokenProxy);
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
        return UUPSProxyDeployer.deployUsingCreateX("RLCCrosschainToken", "", initData, createxFactory, createxSalt);
    }
}

contract Upgrade is Script {
    function run() external pure {
        revert('Not implemented!');
    }
}
