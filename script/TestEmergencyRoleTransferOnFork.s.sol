// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {
    IAccessControlDefaultAdminRules
} from "@openzeppelin/contracts/access/extensions/IAccessControlDefaultAdminRules.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {RLCLiquidityUnifier} from "../src/RLCLiquidityUnifier.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";

/**
 * @title TestEmergencyRoleTransferOnFork
 * @dev Script to test the emergency role transfer on a fork of Ethereum Sepolia or Arbitrum Sepolia
 *
 * This script simulates the complete role transfer process on a local fork:
 * 1. Verifies compromised address has all roles
 * 2. Grants roles to new address and begins admin transfer
 * 3. Fast forwards past delay period
 * 4. Accepts admin role and revokes old roles
 * 5. Verifies new address has all roles and old address has none
 *
 * Usage:
 *   # For Arbitrum Sepolia:
 *   # Start fork in terminal 1:
 *   anvil --fork-url $ARBITRUM_SEPOLIA_RPC_URL --port 8546
 *
 *   # Run test in terminal 2:
 *   CHAIN=arbitrum_sepolia forge script script/TestEmergencyRoleTransferOnFork.s.sol:TestEmergencyRoleTransferOnFork \
 *     --rpc-url http://localhost:8546 \
 *     --broadcast \
 *     -vv
 *
 *   # For Ethereum Sepolia:
 *   # Start fork in terminal 1:
 *   anvil --fork-url $SEPOLIA_RPC_URL --port 8546
 *
 *   # Run test in terminal 2:
 *   CHAIN=sepolia forge script script/TestEmergencyRoleTransferOnFork.s.sol:TestEmergencyRoleTransferOnFork \
 *     --rpc-url http://localhost:8546 \
 *     --broadcast \
 *     -vv
 */
contract TestEmergencyRoleTransferOnFork is Script {
    // Contract instances (will be initialized based on chain)
    IAccessControlDefaultAdminRules public tokenContract;
    IexecLayerZeroBridge public iexecLayerZeroBridge;

    // Chain configuration
    string public chain;
    bool public isApprovalRequired;

    // Compromised address (has all roles)
    address public constant OLD_ADDRESS = 0x9990cfb1Feb7f47297F54bef4d4EbeDf6c5463a3;

    // New secure address for testing
    address public newAddress;

    // Role identifiers
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");

    function run() external {
        // Get chain from environment (defaults to arbitrum_sepolia for backward compatibility)
        chain = vm.envOr("CHAIN", string("arbitrum_sepolia"));

        // Load config
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        isApprovalRequired = params.approvalRequired;

        // Initialize contracts based on chain
        if (isApprovalRequired) {
            // Ethereum Sepolia: Use RLCLiquidityUnifier
            tokenContract = IAccessControlDefaultAdminRules(params.rlcLiquidityUnifierAddress);
            console.log("Using RLCLiquidityUnifier at:", params.rlcLiquidityUnifierAddress);
        } else {
            // Arbitrum Sepolia: Use RLCCrosschainToken
            tokenContract = IAccessControlDefaultAdminRules(params.rlcCrosschainTokenAddress);
            console.log("Using RLCCrosschainToken at:", params.rlcCrosschainTokenAddress);
        }

        iexecLayerZeroBridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);
        console.log("Using IexecLayerZeroBridge at:", params.iexecLayerZeroBridgeAddress);

        // Generate a new address for testing
        newAddress = makeAddr("newSecureAddress");

        console.log("========================================");
        console.log("Testing Emergency Role Transfer on Fork");
        console.log("========================================");
        console.log("Chain:", chain);
        console.log("");
        console.log("Old (compromised) address:", OLD_ADDRESS);
        console.log("New (secure) address:     ", newAddress);
        console.log("");

        // Step 1: Verify initial state
        console.log("--- STEP 1: Verify Initial State ---");
        verifyOldAddressHasRoles();
        verifyNewAddressHasNoRoles();
        console.log("");

        // Step 2: Grant roles and begin admin transfer (as old address)
        console.log("--- STEP 2: Grant Roles & Begin Transfer ---");
        grantRolesAndBeginTransfer();
        console.log("");

        // Step 3: Verify intermediate state
        console.log("--- STEP 3: Verify Intermediate State ---");
        verifyIntermediateState();
        console.log("");

        // Step 4: Fast forward past delay period
        console.log("--- STEP 4: Fast Forward Past Delay Period ---");
        fastForwardPastDelay();
        console.log("");

        // Step 5: Accept admin and revoke old roles (as new address)
        console.log("--- STEP 5: Accept Admin & Revoke Old Roles ---");
        acceptAdminAndRevokeOldRoles();
        console.log("");

        // Step 6: Verify final state
        console.log("--- STEP 6: Verify Final State ---");
        verifyFinalState();
        console.log("");

        console.log("========================================");
        console.log("OK ALL TESTS PASSED!");
        console.log("========================================");
    }

    function verifyOldAddressHasRoles() internal view {
        console.log("Verifying old address has roles...");

        // Check Token Contract (RLCCrosschainToken or RLCLiquidityUnifier)
        string memory tokenName = isApprovalRequired ? "RLCLiquidityUnifier" : "RLCCrosschainToken";
        bool hasDefaultAdmin = tokenContract.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS);
        bool hasUpgrader = tokenContract.hasRole(UPGRADER_ROLE, OLD_ADDRESS);
        bool hasPauser = tokenContract.hasRole(PAUSER_ROLE, OLD_ADDRESS);

        console.log(tokenName, ":");
        console.log("  DEFAULT_ADMIN_ROLE:", hasDefaultAdmin ? "OK" : "MISSING");
        console.log("  UPGRADER_ROLE:     ", hasUpgrader ? "OK" : "MISSING");
        console.log("  PAUSER_ROLE:       ", hasPauser ? "OK (if present)" : "NOT SET (will skip)");

        require(hasDefaultAdmin, string(abi.encodePacked("Old address missing DEFAULT_ADMIN_ROLE on ", tokenName)));
        require(hasUpgrader, string(abi.encodePacked("Old address missing UPGRADER_ROLE on ", tokenName)));
        // Note: PAUSER_ROLE might not be set, which is okay

        // Check IexecLayerZeroBridge
        bool hasBridgeDefaultAdmin = iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS);
        bool hasBridgeUpgrader = iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, OLD_ADDRESS);
        bool hasBridgePauser = iexecLayerZeroBridge.hasRole(PAUSER_ROLE, OLD_ADDRESS);

        console.log("IexecLayerZeroBridge:");
        console.log("  DEFAULT_ADMIN_ROLE:", hasBridgeDefaultAdmin ? "OK" : "MISSING");
        console.log("  UPGRADER_ROLE:     ", hasBridgeUpgrader ? "OK" : "MISSING");
        console.log("  PAUSER_ROLE:       ", hasBridgePauser ? "OK (if present)" : "NOT SET (will skip)");

        require(hasBridgeDefaultAdmin, "Old address missing DEFAULT_ADMIN_ROLE on bridge");
        require(hasBridgeUpgrader, "Old address missing UPGRADER_ROLE on bridge");
        // Note: PAUSER_ROLE might not be set, which is okay

        console.log("OK Old address has core roles (ADMIN + UPGRADER)");
    }

    function verifyNewAddressHasNoRoles() internal view {
        console.log("Verifying new address has no roles...");

        require(!tokenContract.hasRole(DEFAULT_ADMIN_ROLE, newAddress), "New address already has admin on token");
        require(!tokenContract.hasRole(UPGRADER_ROLE, newAddress), "New address already has upgrader on token");
        require(!tokenContract.hasRole(PAUSER_ROLE, newAddress), "New address already has pauser on token");

        require(
            !iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, newAddress), "New address already has admin on bridge"
        );
        require(!iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAddress), "New address already has upgrader on bridge");
        require(!iexecLayerZeroBridge.hasRole(PAUSER_ROLE, newAddress), "New address already has pauser on bridge");

        console.log("OK New address has no roles (as expected)");
    }

    function grantRolesAndBeginTransfer() internal {
        console.log("Impersonating old address to grant roles...");

        vm.startBroadcast(OLD_ADDRESS);

        // Grant roles on Token Contract
        string memory tokenName = isApprovalRequired ? "RLCLiquidityUnifier" : "RLCCrosschainToken";
        console.log(string(abi.encodePacked("Granting roles on ", tokenName, "...")));

        tokenContract.grantRole(UPGRADER_ROLE, newAddress);
        console.log("  - UPGRADER_ROLE granted");

        // Only grant PAUSER_ROLE if old address has it
        if (tokenContract.hasRole(PAUSER_ROLE, OLD_ADDRESS)) {
            tokenContract.grantRole(PAUSER_ROLE, newAddress);
            console.log("  - PAUSER_ROLE granted");
        } else {
            console.log("  - PAUSER_ROLE (skipped - old address doesn't have it)");
        }

        // Only grant TOKEN_BRIDGE_ROLE for RLCCrosschainToken (not for RLCLiquidityUnifier)
        if (!isApprovalRequired) {
            tokenContract.grantRole(TOKEN_BRIDGE_ROLE, newAddress);
            console.log("  - TOKEN_BRIDGE_ROLE granted");
        }

        console.log(string(abi.encodePacked("Beginning admin transfer on ", tokenName, "...")));
        tokenContract.beginDefaultAdminTransfer(newAddress);
        (address pendingAdminToken, uint48 scheduleToken) = tokenContract.pendingDefaultAdmin();
        console.log("  - Pending admin:", pendingAdminToken);
        console.log("  - Scheduled for:", uint256(scheduleToken));

        // Grant roles on IexecLayerZeroBridge
        console.log("Granting roles on IexecLayerZeroBridge...");
        iexecLayerZeroBridge.grantRole(UPGRADER_ROLE, newAddress);
        console.log("  - UPGRADER_ROLE granted");

        // Only grant PAUSER_ROLE if old address has it
        if (iexecLayerZeroBridge.hasRole(PAUSER_ROLE, OLD_ADDRESS)) {
            iexecLayerZeroBridge.grantRole(PAUSER_ROLE, newAddress);
            console.log("  - PAUSER_ROLE granted");
        } else {
            console.log("  - PAUSER_ROLE (skipped - old address doesn't have it)");
        }

        console.log("Beginning admin transfer on IexecLayerZeroBridge...");
        iexecLayerZeroBridge.beginDefaultAdminTransfer(newAddress);
        (address pendingAdminBridge, uint48 scheduleBridge) = iexecLayerZeroBridge.pendingDefaultAdmin();
        console.log("  - Pending admin:", pendingAdminBridge);
        console.log("  - Scheduled for:", uint256(scheduleBridge));

        vm.stopBroadcast();

        console.log("OK Roles granted and admin transfer begun");
    }

    function verifyIntermediateState() internal view {
        console.log("Verifying intermediate state (after grant, before accept)...");

        // New address should have non-admin roles
        console.log("Checking new address has operational roles...");
        require(tokenContract.hasRole(UPGRADER_ROLE, newAddress), "New address missing UPGRADER_ROLE on token");

        // TOKEN_BRIDGE_ROLE only exists on RLCCrosschainToken (not RLCLiquidityUnifier)
        if (!isApprovalRequired) {
            require(
                tokenContract.hasRole(TOKEN_BRIDGE_ROLE, newAddress), "New address missing TOKEN_BRIDGE_ROLE on token"
            );
        }

        require(iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAddress), "New address missing UPGRADER_ROLE on bridge");

        // New address should NOT have admin role yet
        require(
            !tokenContract.hasRole(DEFAULT_ADMIN_ROLE, newAddress),
            "New address should not have DEFAULT_ADMIN_ROLE yet on token"
        );
        require(
            !iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, newAddress),
            "New address should not have DEFAULT_ADMIN_ROLE yet on bridge"
        );

        // Old address should still have admin role
        console.log("Checking old address still has admin role...");
        require(
            tokenContract.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS),
            "Old address should still have DEFAULT_ADMIN_ROLE on token"
        );
        require(
            iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS),
            "Old address should still have DEFAULT_ADMIN_ROLE on bridge"
        );

        console.log("OK Intermediate state verified");
    }

    function fastForwardPastDelay() internal {
        (, uint48 scheduleToken) = tokenContract.pendingDefaultAdmin();
        (, uint48 scheduleBridge) = iexecLayerZeroBridge.pendingDefaultAdmin();

        uint48 maxSchedule = scheduleToken > scheduleBridge ? scheduleToken : scheduleBridge;

        console.log("Current timestamp:", block.timestamp);
        console.log("Delay until:     ", uint256(maxSchedule));
        console.log("Fast forwarding to:", uint256(maxSchedule) + 1);

        vm.warp(uint256(maxSchedule) + 1);

        console.log("OK Fast forwarded past delay period");
        console.log("New timestamp:   ", block.timestamp);
    }

    function acceptAdminAndRevokeOldRoles() internal {
        console.log("Impersonating new address to accept admin and revoke old roles...");

        vm.startBroadcast(newAddress);

        // Accept admin on Token Contract
        string memory tokenName = isApprovalRequired ? "RLCLiquidityUnifier" : "RLCCrosschainToken";
        console.log(string(abi.encodePacked("Accepting admin on ", tokenName, "...")));
        tokenContract.acceptDefaultAdminTransfer();
        address newAdminToken = tokenContract.defaultAdmin();
        console.log("  - New admin confirmed:", newAdminToken);
        require(newAdminToken == newAddress, "Admin transfer failed on token");

        // Revoke roles from old address on token
        console.log(string(abi.encodePacked("Revoking roles from old address on ", tokenName, "...")));
        tokenContract.revokeRole(UPGRADER_ROLE, OLD_ADDRESS);
        console.log("  - UPGRADER_ROLE revoked");

        if (tokenContract.hasRole(PAUSER_ROLE, OLD_ADDRESS)) {
            tokenContract.revokeRole(PAUSER_ROLE, OLD_ADDRESS);
            console.log("  - PAUSER_ROLE revoked");
        }

        // TOKEN_BRIDGE_ROLE only exists on RLCCrosschainToken
        if (!isApprovalRequired && tokenContract.hasRole(TOKEN_BRIDGE_ROLE, OLD_ADDRESS)) {
            tokenContract.revokeRole(TOKEN_BRIDGE_ROLE, OLD_ADDRESS);
            console.log("  - TOKEN_BRIDGE_ROLE revoked");
        }

        // Accept admin on IexecLayerZeroBridge
        console.log("Accepting admin on IexecLayerZeroBridge...");
        iexecLayerZeroBridge.acceptDefaultAdminTransfer();
        address newAdminBridge = iexecLayerZeroBridge.defaultAdmin();
        console.log("  - New admin confirmed:", newAdminBridge);
        require(newAdminBridge == newAddress, "Admin transfer failed on bridge");

        // Revoke roles from old address on bridge
        console.log("Revoking roles from old address on IexecLayerZeroBridge...");
        iexecLayerZeroBridge.revokeRole(UPGRADER_ROLE, OLD_ADDRESS);
        console.log("  - UPGRADER_ROLE revoked");

        if (iexecLayerZeroBridge.hasRole(PAUSER_ROLE, OLD_ADDRESS)) {
            iexecLayerZeroBridge.revokeRole(PAUSER_ROLE, OLD_ADDRESS);
            console.log("  - PAUSER_ROLE revoked");
        }

        vm.stopBroadcast();

        console.log("OK Admin accepted and old roles revoked");
    }

    function verifyFinalState() internal view {
        console.log("Verifying final state...");

        string memory tokenName = isApprovalRequired ? "RLCLiquidityUnifier" : "RLCCrosschainToken";

        // New address should have all roles
        console.log("Checking new address has all transferred roles...");
        require(
            tokenContract.hasRole(DEFAULT_ADMIN_ROLE, newAddress),
            string(abi.encodePacked("New address missing DEFAULT_ADMIN_ROLE on ", tokenName))
        );
        require(
            tokenContract.hasRole(UPGRADER_ROLE, newAddress),
            string(abi.encodePacked("New address missing UPGRADER_ROLE on ", tokenName))
        );

        // TOKEN_BRIDGE_ROLE only exists on RLCCrosschainToken
        if (!isApprovalRequired) {
            require(
                tokenContract.hasRole(TOKEN_BRIDGE_ROLE, newAddress),
                string(abi.encodePacked("New address missing TOKEN_BRIDGE_ROLE on ", tokenName))
            );
        }

        require(
            iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, newAddress),
            "New address missing DEFAULT_ADMIN_ROLE on bridge"
        );
        require(iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, newAddress), "New address missing UPGRADER_ROLE on bridge");

        console.log(string(abi.encodePacked(tokenName, " - New address:")));
        console.log("  DEFAULT_ADMIN_ROLE: OK");
        console.log("  UPGRADER_ROLE:      OK");
        if (!isApprovalRequired) {
            console.log("  TOKEN_BRIDGE_ROLE:  OK");
        }

        console.log("IexecLayerZeroBridge - New address:");
        console.log("  DEFAULT_ADMIN_ROLE: OK");
        console.log("  UPGRADER_ROLE:      OK");

        // Old address should have NO roles
        console.log("Checking old address has no critical roles...");
        require(
            !tokenContract.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS),
            string(abi.encodePacked("Old address still has DEFAULT_ADMIN_ROLE on ", tokenName))
        );
        require(
            !tokenContract.hasRole(UPGRADER_ROLE, OLD_ADDRESS),
            string(abi.encodePacked("Old address still has UPGRADER_ROLE on ", tokenName))
        );

        require(
            !iexecLayerZeroBridge.hasRole(DEFAULT_ADMIN_ROLE, OLD_ADDRESS),
            "Old address still has DEFAULT_ADMIN_ROLE on bridge"
        );
        require(
            !iexecLayerZeroBridge.hasRole(UPGRADER_ROLE, OLD_ADDRESS), "Old address still has UPGRADER_ROLE on bridge"
        );

        console.log(string(abi.encodePacked(tokenName, " - Old address:")));
        console.log("  Critical roles revoked: OK");

        console.log("IexecLayerZeroBridge - Old address:");
        console.log("  Critical roles revoked: OK");

        console.log("OK Final state verified - Transfer complete!");
    }
}
