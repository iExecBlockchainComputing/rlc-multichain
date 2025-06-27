// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {ConfigLib, ConfigUtils} from "./lib/ConfigLib.sol";

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

        address implementationAddress = Upgrades.getImplementationAddress(rlcCrosschainTokenProxy);
        ConfigUtils.updateConfigAddress(chain, "rlcCrosschainTokenAddress", rlcCrosschainTokenProxy);
        ConfigUtils.updateConfigAddress(chain, "rlcCrosschainTokenImplementation", implementationAddress);
//          Updating config.json: .chains.arbitrum_sepolia.rlcCrosschainTokenAddress
//    Updated config.json:
//      Chain: arbitrum_sepolia
//      Field: rlcCrosschainTokenAddress
//      Address: 0xA6b3Da1010f00c55cfd899BE23B8Ece1130DeF85
//   Updating config.json: .chains.arbitrum_sepolia.rlcCrosschainTokenImplementation
//    Updated config.json:
//      Chain: arbitrum_sepolia
//      Field: rlcCrosschainTokenImplementation
//      Address: 0x63E0CE477361f0923E94B225975cC1DF8be33910
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
