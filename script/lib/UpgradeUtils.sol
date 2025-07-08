// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/console.sol";

/**
 * @title UpgradeUtils
 * @notice Utility library for handling UUPS upgrades in a parameterized way
 */
library UpgradeUtils {
    function executeUpgrade(
        address proxyAddress,
        string memory contractName,
        bytes memory constructorData,
        bytes memory initData
    ) internal returns (address newImplementation) {
        Options memory opts;
        opts.constructorData = constructorData;
        // Ignore checks related to LayerZero contracts:
        // - OAppSenderUpgradeable
        // - OAppReceiverUpgradeable
        // - OFTCoreUpgradeable
        // - OAppCoreUpgradeable
        opts.unsafeAllow = "constructor,state-variable-immutable,missing-initializer-call";
        Upgrades.upgradeProxy(proxyAddress, contractName, initData, opts);
        newImplementation = Upgrades.getImplementationAddress(proxyAddress);
        console.log("Upgraded", contractName, " proxy to new implementation", newImplementation);
        return newImplementation;
    }
}
