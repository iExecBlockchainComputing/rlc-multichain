// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdConstants} from "forge-std/StdConstants.sol";

/**
 * @title UpgradeUtils
 * @notice Utility library for handling UUPS upgrades in a parameterized way
 */
library UpgradeUtils {
    Vm private constant vm = StdConstants.VM;
    enum ContractType {
        OFT,
        ADAPTER,
        GENERIC
    }

    struct UpgradeParams {
        address proxyAddress;
        string contractName;
        address lzEndpoint;
        address rlcToken; // Only used for ADAPTER type, ignored for OFT
        ContractType contractType;
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
     * @notice Executes an OFT upgrade with V2 initialization
     * @param params Upgrade parameters (rlcToken field is ignored for OFT)
     * @return newImplementationAddress Address of the new implementation
     */
    function executeUpgradeOFT(UpgradeParams memory params) internal returns (address) {
        return _executeUpgradeWithInit(
            params,
            abi.encodeWithSignature("initializeV2(uint256)", params.newStateVariable)
        );
    }

    /**
     * @notice Executes an Adapter upgrade with V2 initialization
     * @param params Upgrade parameters (rlcToken field is required for ADAPTER)
     * @return newImplementationAddress Address of the new implementation
     */
    function executeUpgradeAdapter(UpgradeParams memory params) internal returns (address) {
        require(params.rlcToken != address(0), "UpgradeUtils: RLC token address required for Adapter upgrades");
        return _executeUpgradeWithInit(
            params,
            abi.encodeWithSignature("initializeV2(uint256)", params.newStateVariable)
        );
    }

    /**
     * @notice Executes a generic upgrade with custom init data
     * @param params Upgrade parameters
     * @param initData Custom initialization data
     * @return newImplementationAddress Address of the new implementation
     */
    function executeUpgradeGeneric(UpgradeParams memory params, bytes memory initData) internal returns (address) {
        return _executeUpgradeWithInit(params, initData);
    }

    /**
     * @notice Executes upgrade based on contract type
     * @param params Upgrade parameters
     * @return newImplementationAddress Address of the new implementation
     */
    function executeUpgrade(UpgradeParams memory params) internal returns (address) {
        if (params.contractType == ContractType.OFT) {
            return executeUpgradeOFT(params);
        } else if (params.contractType == ContractType.ADAPTER) {
            return executeUpgradeAdapter(params);
        } else {
            // Generic upgrade without initialization
            return _executeUpgradeWithInit(params, "");
        }
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
     * @dev Internal function to execute upgrade with initialization
     * @param params Upgrade parameters
     * @param initData Initialization data
     * @return newImplementationAddress Address of the new implementation
     */
    function _executeUpgradeWithInit(
        UpgradeParams memory params, 
        bytes memory initData
    ) private returns (address) {
        Options memory opts = _buildOptions(params);
        
        Upgrades.upgradeProxy(params.proxyAddress, params.contractName, initData, opts);
        
        address newImplementation = Upgrades.getImplementationAddress(params.proxyAddress);
        emit UpgradeExecuted(params.contractName, params.proxyAddress, newImplementation);
        
        return newImplementation;
    }

    /**
     * @notice Builds Options struct for upgrades
     * @param params Upgrade parameters
     * @return opts Configured Options struct
     */
    function _buildOptions(UpgradeParams memory params) private pure returns (Options memory opts) {
        if (params.contractType == ContractType.ADAPTER) {
            opts.constructorData = abi.encode( params.rlcToken, params.lzEndpoint);
        } else if (params.contractType == ContractType.OFT) {
            opts.constructorData = abi.encode(params.lzEndpoint);
        } else {
            opts.constructorData = abi.encode(params.lzEndpoint);
        }
        
        if (params.skipChecks) {
            opts.unsafeSkipAllChecks = true;
        }
    }
}
