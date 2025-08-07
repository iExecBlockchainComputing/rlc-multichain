// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {RLCLiquidityUnifier} from "../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";

/**
 * @title BeginTransferAdminRole
 * @dev Script to transfer the default admin role to a new admin address
 * for all deployed smart contracts on the current chain.
 */
contract BeginTransferAdminRole is Script {

    /**
     * @notice Validates that the new admin is different from the current admin
     * @param currentDefaultAdmin The current admin address
     * @param newAdmin The new admin address
     */
    function validateAdminTransfer(address currentDefaultAdmin, address newAdmin) internal pure {
        require(
            currentDefaultAdmin != newAdmin,
            "BeginTransferAdminRole: New admin must be different from current admin"
        );
    }

    /**
     * @notice Transfers the default admin role for any contract implementing AccessControlDefaultAdminRulesUpgradeable
     * @param contractAddress The address of the contract
     * @param newAdmin The new admin address
     * @param contractName The name of the contract for logging purposes
     */
    function transferContractAdmin(address contractAddress, address newAdmin, string memory contractName) internal {
        AccessControlDefaultAdminRulesUpgradeable adminContract = AccessControlDefaultAdminRulesUpgradeable(contractAddress);

        address currentAdmin = adminContract.defaultAdmin();
        console.log("Current admin for", contractName, ":", currentAdmin);
        validateAdminTransfer(currentAdmin, newAdmin);

        adminContract.beginDefaultAdminTransfer(newAdmin);
        
        console.log("Admin transfer initiated for", contractName, "at:", contractAddress);
    }

    /**
     * @notice Transfers the default admin role to a new admin for all contracts on the current chain
     * @param newAdmin The address that will become the new default admin
     * @dev This function automatically detects which contracts are deployed on the current chain
     * based on the configuration and transfers admin roles accordingly
     */
    function run(address newAdmin) external {
        require(newAdmin != address(0), "BeginTransferAdminRole: New admin cannot be zero address");

        string memory chain = vm.envString("CHAIN");
        console.log("Starting admin role transfer on chain:", chain);
        console.log("New admin address:", newAdmin);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        if (params.approvalRequired) {
            transferContractAdmin(params.rlcLiquidityUnifierAddress, newAdmin, "RLCLiquidityUnifier");
        } else {
            transferContractAdmin(params.rlcCrosschainTokenAddress, newAdmin, "RLCCrosschainToken");
        }
        transferContractAdmin(params.iexecLayerZeroBridgeAddress, newAdmin, "IexecLayerZeroBridge");
        vm.stopBroadcast();
    }
}

/**
 * @title AcceptAdminRole
 * @dev Script to accept the default admin role transfer for all contracts on the current chain.
 * This script should be run by the new admin after the BeginTransferAdminRole script has been executed.
 */
contract AcceptAdminRole is Script {
    /**
     * @notice Accepts the default admin role transfer for any contract implementing AccessControlDefaultAdminRulesUpgradeable
     * @param contractAddress The address of the contract
     * @param contractName The name of the contract for logging purposes
     */
    function acceptContractAdmin(address contractAddress, string memory contractName) internal {
        console.log("Accepting admin role for", contractName, "at:", contractAddress);
        AccessControlDefaultAdminRulesUpgradeable adminContract = AccessControlDefaultAdminRulesUpgradeable(contractAddress);
        adminContract.acceptDefaultAdminTransfer();
        console.log("New admin for", contractName, ":", adminContract.defaultAdmin());
    }

    /**
     * @notice Accepts the default admin role transfer for all contracts on the current chain
     * @dev This function should be called by the new admin to complete the transfer process
     */
    function run() external {
        string memory chain = vm.envString("CHAIN");
        console.log("Accepting admin role transfer on chain:", chain);
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        if (params.approvalRequired) {
            acceptContractAdmin(params.rlcLiquidityUnifierAddress, "RLCLiquidityUnifier");
        } else {
            acceptContractAdmin(params.rlcCrosschainTokenAddress, "RLCCrosschainToken");
        }
        acceptContractAdmin(params.iexecLayerZeroBridgeAddress, "IexecLayerZeroBridge");
        vm.stopBroadcast();
    }
}