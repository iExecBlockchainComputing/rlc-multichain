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
 * @title TransferAdminRole
 * @dev Script to transfer the default admin role to a new admin address
 * for all deployed smart contracts on the current chain.
 */
contract TransferAdminRole is Script {
    
    /**
     * @notice Transfers the default admin role to a new admin for all contracts on the current chain
     * @param newAdmin The address that will become the new default admin
     * @dev This function automatically detects which contracts are deployed on the current chain
     * based on the configuration and transfers admin roles accordingly
     */
    function run(address newAdmin) external {
        require(newAdmin != address(0), "TransferAdminRole: New admin cannot be zero address");
        
        string memory chain = vm.envString("CHAIN");
        console.log("Starting admin role transfer on chain:", chain);
        console.log("New admin address:", newAdmin);
        
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        
        vm.startBroadcast();
        
        // Transfer admin role for contracts deployed on this chain
        if (params.approvalRequired) {
            // This is a mainnet chain (Ethereum/Sepolia) - has RLCLiquidityUnifier
            transferRLCLiquidityUnifierAdmin(params.rlcLiquidityUnifierAddress, newAdmin);
        } else {
            // This is a Layer 2 chain (Arbitrum/Arbitrum Sepolia) - has RLCCrosschainToken
            transferRLCCrosschainTokenAdmin(params.rlcCrosschainTokenAddress, newAdmin);
        }
        
        // All chains have IexecLayerZeroBridge
        transferIexecLayerZeroBridgeAdmin(params.iexecLayerZeroBridgeAddress, newAdmin);
        
        vm.stopBroadcast();
        
        console.log("Admin role transfer completed successfully on chain:", chain);
    }
    
    /**
     * @notice Transfers admin role for RLCLiquidityUnifier contract
     * @param contractAddress The address of the RLCLiquidityUnifier contract
     * @param newAdmin The new admin address
     */
    function transferRLCLiquidityUnifierAdmin(address contractAddress, address newAdmin) internal {
        require(contractAddress != address(0), "TransferAdminRole: RLCLiquidityUnifier address cannot be zero");
        
        console.log("Transferring admin role for RLCLiquidityUnifier at:", contractAddress);
        
        RLCLiquidityUnifier liquidityUnifier = RLCLiquidityUnifier(contractAddress);
        
        // Get current admin to verify permissions
        address currentAdmin = liquidityUnifier.owner();
        console.log("Current admin:", currentAdmin);
        
        // Begin the admin transfer process
        liquidityUnifier.beginDefaultAdminTransfer(newAdmin);
        
        console.log("Admin transfer initiated for RLCLiquidityUnifier");
        console.log("New admin must call acceptDefaultAdminTransfer() to complete the transfer");
    }
    
    /**
     * @notice Transfers admin role for RLCCrosschainToken contract
     * @param contractAddress The address of the RLCCrosschainToken contract
     * @param newAdmin The new admin address
     */
    function transferRLCCrosschainTokenAdmin(address contractAddress, address newAdmin) internal {
        require(contractAddress != address(0), "TransferAdminRole: RLCCrosschainToken address cannot be zero");
        
        console.log("Transferring admin role for RLCCrosschainToken at:", contractAddress);
        
        RLCCrosschainToken crosschainToken = RLCCrosschainToken(contractAddress);
        
        // Get current admin to verify permissions
        address currentAdmin = crosschainToken.owner();
        console.log("Current admin:", currentAdmin);
        
        // Begin the admin transfer process
        crosschainToken.beginDefaultAdminTransfer(newAdmin);
        
        console.log("Admin transfer initiated for RLCCrosschainToken");
        console.log("New admin must call acceptDefaultAdminTransfer() to complete the transfer");
    }
    
    /**
     * @notice Transfers admin role for IexecLayerZeroBridge contract
     * @param contractAddress The address of the IexecLayerZeroBridge contract
     * @param newAdmin The new admin address
     */
    function transferIexecLayerZeroBridgeAdmin(address contractAddress, address newAdmin) internal {
        require(contractAddress != address(0), "TransferAdminRole: IexecLayerZeroBridge address cannot be zero");
        
        console.log("Transferring admin role for IexecLayerZeroBridge at:", contractAddress);
        
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(contractAddress);
        
        // Get current admin to verify permissions
        address currentAdmin = bridge.owner();
        console.log("Current admin:", currentAdmin);
        
        // Begin the admin transfer process
        bridge.beginDefaultAdminTransfer(newAdmin);
        
        console.log("Admin transfer initiated for IexecLayerZeroBridge");
        console.log("New admin must call acceptDefaultAdminTransfer() to complete the transfer");
    }
}

/**
 * @title AcceptAdminRole
 * @dev Script to accept the default admin role transfer for all contracts on the current chain.
 * This script should be run by the new admin after the TransferAdminRole script has been executed.
 *
 * Usage:
 * forge script script/TransferAdminRole.s.sol:AcceptAdminRole \
 *   --rpc-url <RPC_URL> \
 *   --account <NEW_ADMIN_ACCOUNT> \
 *   --broadcast \
 *   -vvv
 *
 * Environment variables required:
 * - CHAIN: The chain identifier (e.g., "ethereum", "arbitrum", "sepolia", "arbitrum_sepolia")
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
        
        // Accept admin role for contracts deployed on this chain
        if (params.approvalRequired) {
            // This is a mainnet chain (Ethereum/Sepolia) - has RLCLiquidityUnifier
            acceptRLCLiquidityUnifierAdmin(params.rlcLiquidityUnifierAddress);
        } else {
            // This is a Layer 2 chain (Arbitrum/Arbitrum Sepolia) - has RLCCrosschainToken
            acceptRLCCrosschainTokenAdmin(params.rlcCrosschainTokenAddress);
        }
        
        // All chains have IexecLayerZeroBridge
        acceptIexecLayerZeroBridgeAdmin(params.iexecLayerZeroBridgeAddress);
        
        vm.stopBroadcast();
        
        console.log("Admin role transfer acceptance completed successfully on chain:", chain);
    }
    
    /**
     * @notice Accepts admin role for RLCLiquidityUnifier contract
     * @param contractAddress The address of the RLCLiquidityUnifier contract
     */
    function acceptRLCLiquidityUnifierAdmin(address contractAddress) internal {
        require(contractAddress != address(0), "AcceptAdminRole: RLCLiquidityUnifier address cannot be zero");
        
        console.log("Accepting admin role for RLCLiquidityUnifier at:", contractAddress);
        
        RLCLiquidityUnifier liquidityUnifier = RLCLiquidityUnifier(contractAddress);
        
        // Accept the admin transfer
        liquidityUnifier.acceptDefaultAdminTransfer();
        
        console.log("Admin role accepted for RLCLiquidityUnifier");
        console.log("New admin:", liquidityUnifier.owner());
    }
    
    /**
     * @notice Accepts admin role for RLCCrosschainToken contract
     * @param contractAddress The address of the RLCCrosschainToken contract
     */
    function acceptRLCCrosschainTokenAdmin(address contractAddress) internal {
        require(contractAddress != address(0), "AcceptAdminRole: RLCCrosschainToken address cannot be zero");
        
        console.log("Accepting admin role for RLCCrosschainToken at:", contractAddress);
        
        RLCCrosschainToken crosschainToken = RLCCrosschainToken(contractAddress);
        
        // Accept the admin transfer
        crosschainToken.acceptDefaultAdminTransfer();
        
        console.log("Admin role accepted for RLCCrosschainToken");
        console.log("New admin:", crosschainToken.owner());
    }
    
    /**
     * @notice Accepts admin role for IexecLayerZeroBridge contract
     * @param contractAddress The address of the IexecLayerZeroBridge contract
     */
    function acceptIexecLayerZeroBridgeAdmin(address contractAddress) internal {
        require(contractAddress != address(0), "AcceptAdminRole: IexecLayerZeroBridge address cannot be zero");
        
        console.log("Accepting admin role for IexecLayerZeroBridge at:", contractAddress);
        
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(contractAddress);
        
        // Accept the admin transfer
        bridge.acceptDefaultAdminTransfer();
        
        console.log("Admin role accepted for IexecLayerZeroBridge");
        console.log("New admin:", bridge.owner());
    }
}
