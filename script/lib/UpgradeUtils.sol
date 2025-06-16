// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
/**
 * @title UpgradeUtils
 * @notice Utility library for handling UUPS upgrades in a parameterized way
 */
library UpgradeUtils {
    struct UpgradeParams {
        address proxyAddress;
        string contractName;
        address lzEndpoint;
        address rlcToken;
        uint256 newStateVariable; // For initialization
        bool skipChecks;
        bool validateOnly;
    }

    // Events for upgrade tracking
    event UpgradeValidated(string contractName, address indexed proxy);
    event UpgradeExecuted(string contractName, address indexed proxy, address indexed newImplementation);

    /**
     * @notice Validates an upgrade without executing it
     * @param params Upgrade parameters
     */
    function validateUpgrade(UpgradeParams memory params) internal {
        Options memory opts = _buildOptions(params);
        Upgrades.validateUpgrade(params.contractName, opts);
        emit UpgradeValidated(params.contractName, params.proxyAddress);
    }

    /**
     * @notice Executes an Adapter upgrade with V2 initialization
     * @param params Upgrade parameters (rlcToken field is required for ADAPTER)
     * @return newImplementationAddress Address of the new implementation
     */
    function executeUpgrade(UpgradeParams memory params) internal returns (address) {
        Options memory opts = _buildOptions(params);
        bytes memory initData = abi.encodeWithSignature("initializeV2(uint256)", params.newStateVariable);

        Upgrades.upgradeProxy(params.proxyAddress, params.contractName, initData, opts);
        address newImplementation = Upgrades.getImplementationAddress(params.proxyAddress);
        emit UpgradeExecuted(params.contractName, params.proxyAddress, newImplementation);

        return newImplementation;
    }

    /**
     * @notice Validates and executes an upgrade
     * @param params Upgrade parameters
     * @return newImplementationAddress Address of the new implementation
     */
    function validateAndUpgrade(UpgradeParams memory params) internal returns (address) {
        // First validate
        validateUpgrade(params);

        // Then execute
        return executeUpgrade(params);
    }

    /**
     * @notice Builds Options struct for upgrades
     * @param params Upgrade parameters
     * @return opts Configured Options struct
     */
    function _buildOptions(UpgradeParams memory params) private pure returns (Options memory opts) {
        opts.constructorData = abi.encode(params.rlcToken, params.lzEndpoint);
        if (params.skipChecks) {
            opts.unsafeSkipAllChecks = true;
        }
    }
}
