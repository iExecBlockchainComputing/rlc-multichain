// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";

/**
 * @title GrantRolesAndBeginAdminTransfer
 * @dev Script to grant all roles to a new address and begin the admin transfer process.
 * This is step 1 of the role migration process for a compromised address scenario.
 *
 * Usage:
 *   CHAIN=arbitrum_sepolia \
 *   OLD_ADDRESS=0x9990cfb1Feb7f47297F54bef4d4EbeDf6c5463a3 \
 *   NEW_ADDRESS=0x... \
 *   forge script script/TransferAllRoles.s.sol:GrantRolesAndBeginAdminTransfer \
 *   --rpc-url $RPC_URL \
 *   --broadcast \
 *   --account $ACCOUNT
 */
contract GrantRolesAndBeginAdminTransfer is Script {
    /**
     * @notice Main entry point for the script
     * @dev Grants all roles to new address and begins admin transfer
     */
    function run() external {
        address oldAddress = vm.envAddress("OLD_ADDRESS");
        address newAddress = vm.envAddress("NEW_ADDRESS");
        string memory chain = vm.envString("CHAIN");

        console.log("=== Grant Roles and Begin Admin Transfer ===");
        console.log("Chain:", chain);
        console.log("Old (compromised) address:", oldAddress);
        console.log("New (secure) address:", newAddress);
        console.log("");

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        
        // Process RLCCrosschainToken (for non-mainnet chains)
        if (!params.approvalRequired) {
            console.log("Processing RLCCrosschainToken...");
            grantRolesAndBeginAdminTransfer(
                params.rlcCrosschainTokenAddress,
                oldAddress,
                newAddress,
                "RLCCrosschainToken",
                true // has TOKEN_BRIDGE_ROLE
            );
            console.log("");
        }

        // Process IexecLayerZeroBridge
        console.log("Processing IexecLayerZeroBridge...");
        grantRolesAndBeginAdminTransfer(
            params.iexecLayerZeroBridgeAddress,
            oldAddress,
            newAddress,
            "IexecLayerZeroBridge",
            false // no TOKEN_BRIDGE_ROLE on bridge
        );

        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Step 1 Complete ===");
        console.log("Next steps:");
        console.log("1. Wait for the admin transfer delay period to pass");
        console.log("2. Run AcceptAdminRoleAndRevokeOldRoles script with the NEW address");
    }

    /**
     * @notice Grants all roles to new address and begins admin transfer for a contract
     * @param contractAddress The address of the contract
     * @param oldAddress The old (compromised) address
     * @param newAddress The new (secure) address
     * @param contractName The name of the contract for logging
     * @param hasTokenBridgeRole Whether this contract has TOKEN_BRIDGE_ROLE
     */
    function grantRolesAndBeginAdminTransfer(
        address contractAddress,
        address oldAddress,
        address newAddress,
        string memory contractName,
        bool hasTokenBridgeRole
    ) internal {
        IAccessControlDefaultAdminRules contractInstance = IAccessControlDefaultAdminRules(contractAddress);
        
        // Verify old address has admin role
        bytes32 defaultAdminRole = 0x00;
        require(
            contractInstance.hasRole(defaultAdminRole, oldAddress),
            string(abi.encodePacked(contractName, ": Old address is not admin"))
        );

        // Get role identifiers
        bytes32 upgraderRole = keccak256("UPGRADER_ROLE");
        bytes32 pauserRole = keccak256("PAUSER_ROLE");
        
        console.log("  Granting roles to new address...");
        
        // Grant UPGRADER_ROLE
        if (contractInstance.hasRole(upgraderRole, oldAddress)) {
            contractInstance.grantRole(upgraderRole, newAddress);
            console.log("    - UPGRADER_ROLE granted");
        }
        
        // Grant PAUSER_ROLE
        if (contractInstance.hasRole(pauserRole, oldAddress)) {
            contractInstance.grantRole(pauserRole, newAddress);
            console.log("    - PAUSER_ROLE granted");
        }
        
        // Grant TOKEN_BRIDGE_ROLE (only for RLCCrosschainToken)
        if (hasTokenBridgeRole) {
            bytes32 tokenBridgeRole = keccak256("TOKEN_BRIDGE_ROLE");
            if (contractInstance.hasRole(tokenBridgeRole, oldAddress)) {
                contractInstance.grantRole(tokenBridgeRole, newAddress);
                console.log("    - TOKEN_BRIDGE_ROLE granted");
            }
        }
        
        // Begin admin transfer
        console.log("  Beginning DEFAULT_ADMIN_ROLE transfer...");
        contractInstance.beginDefaultAdminTransfer(newAddress);
        
        (address pendingAdmin, uint48 schedule) = contractInstance.pendingDefaultAdmin();
        console.log("    - Pending admin:", pendingAdmin);
        console.log("    - Transfer scheduled for:", uint256(schedule));
        console.log("    - Current block timestamp:", block.timestamp);
    }
}

/**
 * @title AcceptAdminRoleAndRevokeOldRoles
 * @dev Script to accept the admin role transfer and revoke all roles from the old address.
 * This is step 2 of the role migration process.
 *
 * IMPORTANT: This script must be run with the NEW address's private key!
 *
 * Usage:
 *   CHAIN=arbitrum_sepolia \
 *   OLD_ADDRESS=0x9990cfb1Feb7f47297F54bef4d4EbeDf6c5463a3 \
 *   forge script script/TransferAllRoles.s.sol:AcceptAdminRoleAndRevokeOldRoles \
 *   --rpc-url $RPC_URL \
 *   --broadcast \
 *   --account $NEW_ACCOUNT
 */
contract AcceptAdminRoleAndRevokeOldRoles is Script {
    /**
     * @notice Main entry point for the script
     * @dev Accepts admin role and revokes all roles from old address
     */
    function run() external {
        address oldAddress = vm.envAddress("OLD_ADDRESS");
        string memory chain = vm.envString("CHAIN");

        console.log("=== Accept Admin Role and Revoke Old Roles ===");
        console.log("Chain:", chain);
        console.log("Old (compromised) address:", oldAddress);
        console.log("New address (caller):", msg.sender);
        console.log("");

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        
        // Process RLCCrosschainToken (for non-mainnet chains)
        if (!params.approvalRequired) {
            console.log("Processing RLCCrosschainToken...");
            acceptAdminAndRevokeOldRoles(
                params.rlcCrosschainTokenAddress,
                oldAddress,
                "RLCCrosschainToken",
                true // has TOKEN_BRIDGE_ROLE
            );
            console.log("");
        }

        // Process IexecLayerZeroBridge
        console.log("Processing IexecLayerZeroBridge...");
        acceptAdminAndRevokeOldRoles(
            params.iexecLayerZeroBridgeAddress,
            oldAddress,
            "IexecLayerZeroBridge",
            false // no TOKEN_BRIDGE_ROLE on bridge
        );

        vm.stopBroadcast();
        
        console.log("");
        console.log("=== Step 2 Complete ===");
        console.log("All roles have been transferred to the new address!");
        console.log("Old address has been completely removed from all contracts.");
    }

    /**
     * @notice Accepts admin role and revokes all roles from old address
     * @param contractAddress The address of the contract
     * @param oldAddress The old (compromised) address to revoke roles from
     * @param contractName The name of the contract for logging
     * @param hasTokenBridgeRole Whether this contract has TOKEN_BRIDGE_ROLE
     */
    function acceptAdminAndRevokeOldRoles(
        address contractAddress,
        address oldAddress,
        string memory contractName,
        bool hasTokenBridgeRole
    ) internal {
        IAccessControlDefaultAdminRules contractInstance = IAccessControlDefaultAdminRules(contractAddress);
        
        // Accept admin role
        console.log("  Accepting DEFAULT_ADMIN_ROLE...");
        contractInstance.acceptDefaultAdminTransfer();
        
        address newAdmin = contractInstance.defaultAdmin();
        console.log("    - New admin confirmed:", newAdmin);
        require(newAdmin != oldAddress, string(abi.encodePacked(contractName, ": Admin not transferred")));
        
        // Revoke all roles from old address
        console.log("  Revoking all roles from old address...");
        
        bytes32 upgraderRole = keccak256("UPGRADER_ROLE");
        bytes32 pauserRole = keccak256("PAUSER_ROLE");
        bytes32 defaultAdminRole = 0x00;
        
        // Revoke UPGRADER_ROLE
        if (contractInstance.hasRole(upgraderRole, oldAddress)) {
            contractInstance.revokeRole(upgraderRole, oldAddress);
            console.log("    - UPGRADER_ROLE revoked");
        }
        
        // Revoke PAUSER_ROLE
        if (contractInstance.hasRole(pauserRole, oldAddress)) {
            contractInstance.revokeRole(pauserRole, oldAddress);
            console.log("    - PAUSER_ROLE revoked");
        }
        
        // Revoke TOKEN_BRIDGE_ROLE (only for RLCCrosschainToken)
        if (hasTokenBridgeRole) {
            bytes32 tokenBridgeRole = keccak256("TOKEN_BRIDGE_ROLE");
            if (contractInstance.hasRole(tokenBridgeRole, oldAddress)) {
                contractInstance.revokeRole(tokenBridgeRole, oldAddress);
                console.log("    - TOKEN_BRIDGE_ROLE revoked");
            }
        }
        
        // Verify old address no longer has any roles
        bool hasUpgrader = contractInstance.hasRole(upgraderRole, oldAddress);
        bool hasPauser = contractInstance.hasRole(pauserRole, oldAddress);
        bool hasAdmin = contractInstance.hasRole(defaultAdminRole, oldAddress);
        
        require(!hasUpgrader && !hasPauser && !hasAdmin, 
            string(abi.encodePacked(contractName, ": Old address still has roles")));
        
        console.log("    - All roles successfully revoked from old address");
    }
}
