// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @title ConfigLib
 * @dev Library for handling configuration logic across all deployment and operational scripts,
 *      including configuration reading and JSON file updating functionality
 */
library ConfigLib {
    using stdJson for string;

    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @dev Common configuration parameters structure
     */
    struct CommonConfigParams {
        address initialAdmin;
        address initialPauser;
        address initialUpgrader;
        address createxFactory;
        address lzEndpoint;
        uint32 lzChainId;
        address rlcToken; // RLC token address (already deployed on L1)
        bytes32 rlcLiquidityUnifierCreatexSalt; // Salt for CreateX deployment of the RLC Liquidity Unifier
        address rlcLiquidityUnifierAddress; // RLC Liquidity Unifier address (only on L1)
        bytes32 rlcCrosschainTokenCreatexSalt; // Salt for CreateX deployment of the RLC Crosschain Token
        address rlcCrosschainTokenAddress; // RLC Crosschain token address (only on L2)
        bool approvalRequired; // Whether approval is required for the bridgeable token (yes on L1, no on L2)
        bytes32 iexecLayerZeroBridgeCreatexSalt; // Salt for CreateX deployment of the LayerZero bridge
        address iexecLayerZeroBridgeAddress;
    }

    /**
     * @dev Gets the appropriate bridgeable token address based on the chain
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the bridgeable token (RLCLiquidityUnifier on mainnet, RLC Crosschain on L2s)
     */
    function getLiquidityUnifierAddress(string memory config, string memory prefix) internal pure returns (address) {
        return config.readBool(string.concat(prefix, ".approvalRequired"))
            ? config.readAddress(string.concat(prefix, ".rlcLiquidityUnifierAddress"))
            : address(0);
    }
    /**
     * @dev Gets the RLC Crosschain token address based on the chain
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the RLC Crosschain token
     */

    function getRLCCrosschainTokenAddress(string memory config, string memory prefix) internal pure returns (address) {
        return config.readBool(string.concat(prefix, ".approvalRequired"))
            ? address(0)
            : config.readAddress(string.concat(prefix, ".rlcCrosschainTokenAddress"));
    }

    /**
     * @dev Gets the bridgeable token address based on the chains
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the RLC token (native RLC on L1, crosschain token on L2s)
     */
    function getRLCTokenAddress(string memory config, string memory prefix) internal pure returns (address) {
        return config.readBool(string.concat(prefix, ".approvalRequired"))
            ? config.readAddress(string.concat(prefix, ".rlcLiquidityUnifierAddress"))
            : address(0);
    }

    function getAllCreatexParams(string memory config, string memory prefix)
        internal
        pure
        returns (
            bytes32 rlcCrosschainTokenCreatexSalt,
            bytes32 rlcLiquidityUnifierCreatexSalt,
            bytes32 iexecLayerZeroBridgeCreatexSalt
        )
    {
        rlcCrosschainTokenCreatexSalt = bytes32(0);
        rlcLiquidityUnifierCreatexSalt = bytes32(0);
        iexecLayerZeroBridgeCreatexSalt = config.readBytes32(string.concat(prefix, ".iexecLayerZeroBridgeCreatexSalt"));

        if (config.readBool(string.concat(prefix, ".approvalRequired"))) {
            // RLCLiquidityUnifier is deployed.
            rlcLiquidityUnifierCreatexSalt =
                config.readBytes32(string.concat(prefix, ".rlcLiquidityUnifierCreatexSalt"));
        } else {
            // RLCCrosschainToken is deployed.
            rlcCrosschainTokenCreatexSalt = config.readBytes32(string.concat(prefix, ".rlcCrosschainTokenCreatexSalt"));
        }
    }

    /**
     * @dev Reads common configuration parameters from config.json
     * @param chain The current chain identifier
     * @return params Common configuration parameters
     */
    function readCommonConfig(string memory chain) internal view returns (CommonConfigParams memory params) {
        string memory config = vm.readFile("config/config.json");
        string memory prefix = string.concat(".chains.", chain);
        params.initialAdmin = config.readAddress(".initialAdmin");
        params.initialPauser = config.readAddress(".initialPauser");
        params.initialUpgrader = config.readAddress(".initialUpgrader");
        params.createxFactory = config.readAddress(".createxFactory");
        params.rlcToken = getRLCTokenAddress(config, prefix);
        (
            params.rlcCrosschainTokenCreatexSalt,
            params.rlcLiquidityUnifierCreatexSalt,
            params.iexecLayerZeroBridgeCreatexSalt
        ) = getAllCreatexParams(config, prefix);
        params.rlcCrosschainTokenAddress = getRLCCrosschainTokenAddress(config, prefix);
        params.rlcLiquidityUnifierAddress = getLiquidityUnifierAddress(config, prefix);
        params.approvalRequired = config.readBool(string.concat(prefix, ".approvalRequired"));
        params.iexecLayerZeroBridgeAddress = config.readAddress(string.concat(prefix, ".iexecLayerZeroBridgeAddress"));
        params.lzEndpoint = config.readAddress(string.concat(prefix, ".lzEndpointAddress"));
        params.lzChainId = uint32(config.readUint(string.concat(prefix, ".lzChainId")));
    }

    /**
     * @dev Updates the config file with a new address for a specific chain
     * @param chain The chain identifier (e.g., "sepolia", "arbitrum_sepolia")
     * @param fieldName The field name to update (e.g., "iexecLayerZeroBridgeAddress")
     * @param value The address value to set
     */
    function updateConfigAddress(string memory chain, string memory fieldName, address value) internal {
        string memory configPath = "config/config.json";
        // Check if file exists
        if (!vm.exists(configPath)) {
            console.log("Config file not found at:", configPath);
            revert("Config file not found");
        }

        // Read and validate JSON
        string memory content = vm.readFile(configPath);
        _validateJsonContent(content);

        // Convert address to string and create JSON value
        string memory addressString = vm.toString(value);
        string memory jsonValue = string.concat('"', addressString, '"');

        // Create the JSON path: .chains.sepolia.iexecLayerZeroBridgeAddress
        string memory jsonPath = string.concat(".chains.", chain, ".", fieldName);

        console.log("Updating config.json:", jsonPath);

        // Update the JSON file using vm.writeJson
        vm.writeJson(jsonValue, configPath, jsonPath);

        // Ensure the file ends with a newline for proper EOF
        _ensureFileEndsWithNewline(configPath);
    }

    /**
     * @dev Validates JSON content by attempting to parse it
     * @param content The JSON content to validate
     */
    function _validateJsonContent(string memory content) private pure {
        try vm.parseJson(content) {
            // JSON is valid, proceed
        } catch {
            console.log("Invalid JSON in config file");
            revert("Invalid JSON format");
        }
    }

    /**
     * @dev Ensures the config file ends with a newline for proper EOF
     * @param configPath The path to the config file
     */
    function _ensureFileEndsWithNewline(string memory configPath) private {
        // Read the current content
        string memory content = vm.readFile(configPath);

        // Check if the content ends with a newline
        if (!_endsWithNewline(content)) {
            // Append a newline and write back
            string memory contentWithNewline = string.concat(content, "\n");
            vm.writeFile(configPath, contentWithNewline);
        }
    }

    /**
     * @dev Checks if a string ends with a newline character
     * @param str The string to check
     * @return Whether the string ends with a newline
     */
    function _endsWithNewline(string memory str) private pure returns (bool) {
        bytes memory strBytes = bytes(str);

        if (strBytes.length == 0) {
            return false;
        }

        return strBytes[strBytes.length - 1] == bytes1("\n");
    }
}
