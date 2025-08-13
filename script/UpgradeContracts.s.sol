// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ConfigLib} from "./lib/ConfigLib.sol";
import {UpgradeUtils} from "./lib/UpgradeUtils.sol";
import {RLCLiquidityUnifier} from "../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../src/RLCCrosschainToken.sol";
import {IexecLayerZeroBridge} from "../src/bridges/layerZero/IexecLayerZeroBridge.sol";

/**
 * @title UpgradeContracts
 * @dev Script to upgrade contracts that use UPGRADER_ROLE on the current chain.
 *
 * This script handles upgrades for:
 * - RLCLiquidityUnifier (on Ethereum mainnet chains)
 * - RLCCrosschainToken (on Layer 2 chains)
 * - IexecLayerZeroBridge (on all chains)
 *
 * Usage:
 * forge script script/UpgradeContracts.s.sol:UpgradeRLCLiquidityUnifier \
 *   --rpc-url <RPC_URL> \
 *   --account <UPGRADER_ACCOUNT> \
 *   --broadcast \
 *   -vvv \
 *   --sig "run(string)" <NEW_IMPLEMENTATION_CONTRACT_NAME>
 *
 * Environment variables required:
 * - CHAIN: The chain identifier (e.g., "ethereum", "arbitrum", "sepolia", "arbitrum_sepolia")
 */
contract UpgradeRLCLiquidityUnifier is Script {
    /**
     * @notice Upgrades the RLCLiquidityUnifier contract
     * @param newImplementationContractName The name of the new implementation contract
     * @dev This function upgrades the RLCLiquidityUnifier on mainnet chains (Ethereum/Sepolia)
     */
    function run(string memory newImplementationContractName) external {
        string memory chain = vm.envString("CHAIN");
        console.log("Upgrading RLCLiquidityUnifier on chain:", chain);
        console.log("Upgrader address (caller):", tx.origin);
        console.log("New implementation contract:", newImplementationContractName);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        // Verify this is a mainnet chain that has RLCLiquidityUnifier
        require(params.approvalRequired, "UpgradeRLCLiquidityUnifier: This chain does not have RLCLiquidityUnifier");
        require(
            params.rlcLiquidityUnifierAddress != address(0),
            "UpgradeRLCLiquidityUnifier: RLCLiquidityUnifier address cannot be zero"
        );

        RLCLiquidityUnifier liquidityUnifier = RLCLiquidityUnifier(params.rlcLiquidityUnifierAddress);

        // Verify caller has UPGRADER_ROLE
        bytes32 upgraderRole = liquidityUnifier.UPGRADER_ROLE();
        require(
            liquidityUnifier.hasRole(upgraderRole, tx.origin),
            "UpgradeRLCLiquidityUnifier: Caller does not have UPGRADER_ROLE"
        );

        console.log("Current implementation:", Upgrades.getImplementationAddress(params.rlcLiquidityUnifierAddress));
        console.log("Current admin:", liquidityUnifier.owner());

        vm.startBroadcast();

        // Use UpgradeUtils for the upgrade
        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.rlcLiquidityUnifierAddress,
            contractName: newImplementationContractName,
            constructorData: abi.encode(params.rlcToken),
            newStateVariable: 0 // No state variable initialization needed for basic upgrade
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);

        vm.stopBroadcast();

        console.log("Upgrade completed successfully");
        console.log("New implementation:", newImplementation);
        console.log("Proxy address unchanged:", params.rlcLiquidityUnifierAddress);
    }
}

/**
 * @title UpgradeRLCCrosschainToken
 * @dev Script to upgrade the RLCCrosschainToken contract on Layer 2 chains
 */
contract UpgradeRLCCrosschainToken is Script {
    /**
     * @notice Upgrades the RLCCrosschainToken contract
     * @param newImplementationContractName The name of the new implementation contract
     * @dev This function upgrades the RLCCrosschainToken on Layer 2 chains (Arbitrum/Arbitrum Sepolia)
     */
    function run(string memory newImplementationContractName) external {
        string memory chain = vm.envString("CHAIN");
        console.log("Upgrading RLCCrosschainToken on chain:", chain);
        console.log("Upgrader address (caller):", tx.origin);
        console.log("New implementation contract:", newImplementationContractName);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        // Verify this is a Layer 2 chain that has RLCCrosschainToken
        require(!params.approvalRequired, "UpgradeRLCCrosschainToken: This chain does not have RLCCrosschainToken");
        require(
            params.rlcCrosschainTokenAddress != address(0),
            "UpgradeRLCCrosschainToken: RLCCrosschainToken address cannot be zero"
        );

        RLCCrosschainToken crosschainToken = RLCCrosschainToken(params.rlcCrosschainTokenAddress);

        // Verify caller has UPGRADER_ROLE
        bytes32 upgraderRole = crosschainToken.UPGRADER_ROLE();
        require(
            crosschainToken.hasRole(upgraderRole, tx.origin),
            "UpgradeRLCCrosschainToken: Caller does not have UPGRADER_ROLE"
        );

        console.log("Current implementation:", Upgrades.getImplementationAddress(params.rlcCrosschainTokenAddress));
        console.log("Current admin:", crosschainToken.owner());
        console.log("Token name:", crosschainToken.name());
        console.log("Token symbol:", crosschainToken.symbol());

        vm.startBroadcast();

        // Use UpgradeUtils for the upgrade
        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.rlcCrosschainTokenAddress,
            contractName: newImplementationContractName,
            constructorData: "", // No constructor data needed for ERC20 upgradeable
            newStateVariable: 0 // No state variable initialization needed for basic upgrade
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);

        vm.stopBroadcast();

        console.log("Upgrade completed successfully");
        console.log("New implementation:", newImplementation);
        console.log("Proxy address unchanged:", params.rlcCrosschainTokenAddress);
    }
}

/**
 * @title UpgradeIexecLayerZeroBridge
 * @dev Script to upgrade the IexecLayerZeroBridge contract on any chain
 */
contract UpgradeIexecLayerZeroBridge is Script {
    /**
     * @notice Upgrades the IexecLayerZeroBridge contract
     * @param newImplementationContractName The name of the new implementation contract
     * @dev This function upgrades the IexecLayerZeroBridge on any chain
     */
    function run(string memory newImplementationContractName) external {
        string memory chain = vm.envString("CHAIN");
        console.log("Upgrading IexecLayerZeroBridge on chain:", chain);
        console.log("Upgrader address (caller):", tx.origin);
        console.log("New implementation contract:", newImplementationContractName);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);
        require(
            params.iexecLayerZeroBridgeAddress != address(0),
            "UpgradeIexecLayerZeroBridge: Bridge address cannot be zero"
        );

        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress);

        // Verify caller has UPGRADER_ROLE
        bytes32 upgraderRole = bridge.UPGRADER_ROLE();
        require(
            bridge.hasRole(upgraderRole, tx.origin), "UpgradeIexecLayerZeroBridge: Caller does not have UPGRADER_ROLE"
        );

        console.log("Current implementation:", Upgrades.getImplementationAddress(params.iexecLayerZeroBridgeAddress));
        console.log("Current admin:", bridge.owner());
        console.log("Approval required:", bridge.approvalRequired());
        console.log("Bridge paused:", bridge.paused());
        console.log("Outbound paused:", bridge.outboundTransfersPaused());

        vm.startBroadcast();

        // Use UpgradeUtils for the upgrade
        address bridgeableToken =
            params.approvalRequired ? params.rlcLiquidityUnifierAddress : params.rlcCrosschainTokenAddress;
        
        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.iexecLayerZeroBridgeAddress,
            contractName: newImplementationContractName,
            constructorData: abi.encode(params.approvalRequired, bridgeableToken, params.lzEndpoint),
            newStateVariable: 0 // No state variable initialization needed for basic upgrade
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);

        vm.stopBroadcast();

        console.log("Upgrade completed successfully");
        console.log("New implementation:", newImplementation);
        console.log("Proxy address unchanged:", params.iexecLayerZeroBridgeAddress);
    }
}

/**
 * @title UpgradeAllContracts
 * @dev Script to upgrade all contracts on the current chain
 */
contract UpgradeAllContracts is Script {
    /**
     * @notice Upgrades all contracts on the current chain
     * @param newLiquidityUnifierContract The new RLCLiquidityUnifier implementation (empty string to skip)
     * @param newCrosschainTokenContract The new RLCCrosschainToken implementation (empty string to skip)
     * @param newBridgeContract The new IexecLayerZeroBridge implementation (empty string to skip)
     * @dev This function upgrades all relevant contracts based on the chain configuration
     */
    function run(
        string memory newLiquidityUnifierContract,
        string memory newCrosschainTokenContract,
        string memory newBridgeContract
    ) external {
        string memory chain = vm.envString("CHAIN");
        console.log("Upgrading all contracts on chain:", chain);
        console.log("Upgrader address (caller):", tx.origin);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();

        // Upgrade RLCLiquidityUnifier if on mainnet chain and contract name provided
        if (params.approvalRequired && bytes(newLiquidityUnifierContract).length > 0) {
            console.log("\n=== Upgrading RLCLiquidityUnifier ===");
            upgradeRLCLiquidityUnifier(params, newLiquidityUnifierContract);
        }

        // Upgrade RLCCrosschainToken if on Layer 2 chain and contract name provided
        if (!params.approvalRequired && bytes(newCrosschainTokenContract).length > 0) {
            console.log("\n=== Upgrading RLCCrosschainToken ===");
            upgradeRLCCrosschainToken(params, newCrosschainTokenContract);
        }

        // Upgrade IexecLayerZeroBridge if contract name provided
        if (bytes(newBridgeContract).length > 0) {
            console.log("\n=== Upgrading IexecLayerZeroBridge ===");
            upgradeIexecLayerZeroBridge(params, newBridgeContract);
        }

        vm.stopBroadcast();

        console.log("\nAll specified upgrades completed successfully on chain:", chain);
    }

    function upgradeRLCLiquidityUnifier(ConfigLib.CommonConfigParams memory params, string memory newContract)
        internal
    {
        require(params.rlcLiquidityUnifierAddress != address(0), "RLCLiquidityUnifier not deployed");

        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.rlcLiquidityUnifierAddress,
            contractName: newContract,
            constructorData: abi.encode(params.rlcToken),
            newStateVariable: 0
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);
        console.log("RLCLiquidityUnifier upgraded to:", newImplementation);
    }

    function upgradeRLCCrosschainToken(ConfigLib.CommonConfigParams memory params, string memory newContract)
        internal
    {
        require(params.rlcCrosschainTokenAddress != address(0), "RLCCrosschainToken not deployed");

        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.rlcCrosschainTokenAddress,
            contractName: newContract,
            constructorData: "",
            newStateVariable: 0
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);
        console.log("RLCCrosschainToken upgraded to:", newImplementation);
    }

    function upgradeIexecLayerZeroBridge(ConfigLib.CommonConfigParams memory params, string memory newContract)
        internal
    {
        require(params.iexecLayerZeroBridgeAddress != address(0), "IexecLayerZeroBridge not deployed");

        address bridgeableToken =
            params.approvalRequired ? params.rlcLiquidityUnifierAddress : params.rlcCrosschainTokenAddress;
        
        UpgradeUtils.UpgradeParams memory upgradeParams = UpgradeUtils.UpgradeParams({
            proxyAddress: params.iexecLayerZeroBridgeAddress,
            contractName: newContract,
            constructorData: abi.encode(params.approvalRequired, bridgeableToken, params.lzEndpoint),
            newStateVariable: 0
        });

        address newImplementation = UpgradeUtils.executeUpgrade(upgradeParams);
        console.log("IexecLayerZeroBridge upgraded to:", newImplementation);
    }
}

/**
 * @title GetImplementationAddresses
 * @dev Script to check current implementation addresses of all contracts
 */
contract GetImplementationAddresses is Script {
    /**
     * @notice Gets and displays current implementation addresses for all contracts
     * @dev This is a read-only function that doesn't broadcast any transactions
     */
    function run() external view {
        string memory chain = vm.envString("CHAIN");
        console.log("Getting implementation addresses on chain:", chain);

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        console.log("=== CONTRACT IMPLEMENTATION ADDRESSES ===");

        // RLCLiquidityUnifier (mainnet chains only)
        if (params.approvalRequired && params.rlcLiquidityUnifierAddress != address(0)) {
            console.log("\nRLCLiquidityUnifier:");
            console.log("- Proxy:", params.rlcLiquidityUnifierAddress);
            console.log("- Implementation:", Upgrades.getImplementationAddress(params.rlcLiquidityUnifierAddress));
            console.log("- Admin:", RLCLiquidityUnifier(params.rlcLiquidityUnifierAddress).owner());
        }

        // RLCCrosschainToken (Layer 2 chains only)
        if (!params.approvalRequired && params.rlcCrosschainTokenAddress != address(0)) {
            console.log("\nRLCCrosschainToken:");
            console.log("- Proxy:", params.rlcCrosschainTokenAddress);
            console.log("- Implementation:", Upgrades.getImplementationAddress(params.rlcCrosschainTokenAddress));
            console.log("- Admin:", RLCCrosschainToken(params.rlcCrosschainTokenAddress).owner());
        }

        // IexecLayerZeroBridge (all chains)
        if (params.iexecLayerZeroBridgeAddress != address(0)) {
            console.log("\nIexecLayerZeroBridge:");
            console.log("- Proxy:", params.iexecLayerZeroBridgeAddress);
            console.log("- Implementation:", Upgrades.getImplementationAddress(params.iexecLayerZeroBridgeAddress));
            console.log("- Admin:", IexecLayerZeroBridge(params.iexecLayerZeroBridgeAddress).owner());
        }
    }
}
