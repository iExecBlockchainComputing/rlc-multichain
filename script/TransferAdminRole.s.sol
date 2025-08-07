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
            transferRLCLiquidityUnifierAdmin(params.rlcLiquidityUnifierAddress, newAdmin);
        } else {
            transferRLCCrosschainTokenAdmin(params.rlcCrosschainTokenAddress, newAdmin);
        }
        transferIexecLayerZeroBridgeAdmin(params.iexecLayerZeroBridgeAddress, newAdmin);
        vm.stopBroadcast();
    }

    /**
     * @notice Transfers admin role for RLCLiquidityUnifier contract
     * @param contractAddress The address of the RLCLiquidityUnifier contract
     * @param newAdmin The new admin address
     */
    function transferRLCLiquidityUnifierAdmin(address contractAddress, address newAdmin) internal {
        RLCLiquidityUnifier liquidityUnifier = RLCLiquidityUnifier(contractAddress);

        address currentDefaultAdmin = liquidityUnifier.defaultAdmin();
        console.log("Current admin:", currentDefaultAdmin);
        validateAdminTransfer(currentDefaultAdmin, newAdmin);

        liquidityUnifier.beginDefaultAdminTransfer(newAdmin);
        console.log("Admin transfer initiated for RLCLiquidityUnifier at:", contractAddress);
    }

    /**
     * @notice Transfers admin role for RLCCrosschainToken contract
     * @param contractAddress The address of the RLCCrosschainToken contract
     * @param newAdmin The new admin address
     */
    function transferRLCCrosschainTokenAdmin(address contractAddress, address newAdmin) internal {
        RLCCrosschainToken crosschainToken = RLCCrosschainToken(contractAddress);

        address currentDefaultAdmin = crosschainToken.defaultAdmin();
        console.log("Current admin:", currentDefaultAdmin);
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
        crosschainToken.beginDefaultAdminTransfer(newAdmin);
        console.log("Admin transfer initiated for RLCCrosschainToken at:", contractAddress);
    }

    /**
     * @notice Transfers admin role for IexecLayerZeroBridge contract
     * @param contractAddress The address of the IexecLayerZeroBridge contract
     * @param newAdmin The new admin address
     */
    function transferIexecLayerZeroBridgeAdmin(address contractAddress, address newAdmin) internal {
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(contractAddress);

        address currentDefaultAdmin = bridge.defaultAdmin();
        console.log("Current admin:", currentDefaultAdmin);
        validateAdminTransfer(currentDefaultAdmin, newAdmin);
        bridge.beginDefaultAdminTransfer(newAdmin);
        console.log("Admin transfer initiated for IexecLayerZeroBridge at:", contractAddress);
    }
}

/**
 * @title AcceptAdminRole
 * @dev Script to accept the default admin role transfer for all contracts on the current chain.
 * This script should be run by the new admin after the BeginTransferAdminRole script has been executed.
 */
contract AcceptAdminRole is Script {
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
            acceptRLCLiquidityUnifierAdmin(params.rlcLiquidityUnifierAddress);
        } else {
            acceptRLCCrosschainTokenAdmin(params.rlcCrosschainTokenAddress);
        }
        acceptIexecLayerZeroBridgeAdmin(params.iexecLayerZeroBridgeAddress);
        vm.stopBroadcast();
    }

    /**
     * @notice Accepts admin role for RLCLiquidityUnifier contract
     * @param contractAddress The address of the RLCLiquidityUnifier contract
     */
    function acceptRLCLiquidityUnifierAdmin(address contractAddress) internal {
        console.log("Accepting admin role for RLCLiquidityUnifier at:", contractAddress);

        RLCLiquidityUnifier liquidityUnifier = RLCLiquidityUnifier(contractAddress);

        liquidityUnifier.acceptDefaultAdminTransfer();
        console.log("New admin:", liquidityUnifier.defaultAdmin());
    }

    /**
     * @notice Accepts admin role for RLCCrosschainToken contract
     * @param contractAddress The address of the RLCCrosschainToken contract
     */
    function acceptRLCCrosschainTokenAdmin(address contractAddress) internal {
        console.log("Accepting admin role for RLCCrosschainToken at:", contractAddress);

        RLCCrosschainToken crosschainToken = RLCCrosschainToken(contractAddress);

        crosschainToken.acceptDefaultAdminTransfer();
        console.log("New admin:", crosschainToken.defaultAdmin());
    }

    /**
     * @notice Accepts admin role for IexecLayerZeroBridge contract
     * @param contractAddress The address of the IexecLayerZeroBridge contract
     */
    function acceptIexecLayerZeroBridgeAdmin(address contractAddress) internal {
        console.log("Accepting admin role for IexecLayerZeroBridge at:", contractAddress);

        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(contractAddress);

        bridge.acceptDefaultAdminTransfer();
        console.log("New admin:", bridge.defaultAdmin());
    }
}
