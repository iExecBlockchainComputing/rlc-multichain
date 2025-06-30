// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";


/**
 * @title ConfigLib
 * @dev Library for handling configuration logic across all deployment and operational scripts
 */
library ConfigLib {
    using stdJson for string;

    /**
     * @dev Common configuration parameters structure
     */
    struct CommonConfigParams {
        address initialAdmin;
        address initialPauser;
        address initialUpgrader;
        address createxFactory;
        bytes32 createxSalt;
        address lzEndpoint;
        uint32 layerZeroChainId;
        address rlcToken;
        address bridgeableToken;
        address rlcLiquidityUnifier;
        address layerZeroBridge;
    }

    /**
     * @dev Gets the appropriate token address for bridging based on the chain
     * @param config The JSON configuration string
     * @param chain The current chain identifier
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the bridgeable token (RLCLiquidityUnifier on mainnet, RLC CrossChain on L2s)
     */
    function getBridgeableTokenAddress(string memory config, string memory chain, string memory prefix)
        internal
        pure
        returns (address)
    {
        if (keccak256(abi.encodePacked(chain)) == keccak256(abi.encodePacked("sepolia"))) {
            return config.readAddress(string.concat(prefix, ".rlcLiquidityUnifierAddress"));
        } else {
            return config.readAddress(string.concat(prefix, ".rlcCrossChainTokenAddress"));
        }
    }

    /**
     * @dev Gets the liquidity unifier address (only applicable for L1 chains)
     * @param config The JSON configuration string
     * @param chain The current chain identifier
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the liquidity unifier (zero address for L2s)
     */
    function getLiquidityUnifierAddress(string memory config, string memory chain, string memory prefix)
        internal
        pure
        returns (address)
    {
        if (keccak256(abi.encodePacked(chain)) == keccak256(abi.encodePacked("sepolia"))) {
            return config.readAddress(string.concat(prefix, ".rlcLiquidityUnifierAddress"));
        } else {
            return address(0); // Not applicable for L2s
        }
    }

    /**
     * @dev Gets the appropriate RLC token address based on the chain
     * @param config The JSON configuration string
     * @param chain The current chain identifier
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the RLC token (native RLC on L1, crosschain token on L2s)
     */
    function getRLCTokenAddress(string memory config, string memory chain, string memory prefix)
        internal
        pure
        returns (address)
    {
        if (keccak256(abi.encodePacked(chain)) == keccak256(abi.encodePacked("sepolia"))) {
            return config.readAddress(string.concat(prefix, ".rlcAddress"));
        } else {
            return config.readAddress(string.concat(prefix, ".rlcCrossChainTokenAddress"));
        }
    }

    /**
     * @dev Gets the LayerZero bridge address for the specified chain
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the LayerZero bridge contract
     */
    function getLayerZeroBridgeAddress(string memory config, string memory prefix) internal pure returns (address) {
        return config.readAddress(string.concat(prefix, ".iexecLayerZeroBridgeAddress"));
    }

    /**
     * @dev Reads common configuration parameters from config.json
     * @param config The JSON configuration string
     * @param chain The current chain identifier
     * @return params Common configuration parameters
     */
    function readCommonConfig(string memory config, string memory chain)
        internal
        pure
        returns (CommonConfigParams memory params)
    {
        string memory prefix = string.concat(".chains.", chain);

        params.initialAdmin = config.readAddress(".initialAdmin");
        params.initialPauser = config.readAddress(".initialPauser");
        params.initialUpgrader = config.readAddress(".initialUpgrader");
        params.createxFactory = config.readAddress(".createxFactory");
        params.bridgeableToken = getBridgeableTokenAddress(config, chain, prefix);
        params.rlcLiquidityUnifier = getLiquidityUnifierAddress(config, chain, prefix);
        params.rlcToken = getRLCTokenAddress(config, chain, prefix);
        params.lzEndpoint = config.readAddress(string.concat(prefix, ".layerZeroEndpointAddress"));
        params.createxSalt = config.readBytes32(string.concat(prefix, ".iexecLayerZeroBridgeCreatexSalt"));
        params.layerZeroBridge = config.readAddress(string.concat(prefix, ".iexecLayerZeroBridgeAddress"));
        params.layerZeroChainId = uint32(config.readUint(string.concat(prefix, ".layerZeroChainId")));
    }
}

/**
 * @title ConfigUtils
 * @dev Library for updating configuration files with deployed addresses using proper JSON serialization
 */
library ConfigUtils {
    using stdJson for string;
    
    Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /**
     * @dev Updates the config.json file with a new address for a specific chain
     * @param chain The chain identifier (e.g., "sepolia", "arbitrum_sepolia")
     * @param fieldName The field name to update (e.g., "iexecLayerZeroBridgeAddress")
     * @param value The address value to set
     */
    function updateConfigAddress(string memory chain, string memory fieldName, address value) internal {
        updateConfigAddress(chain, fieldName, value, "config/config.json");
    }

    /**
     * @dev Updates the config file with a new address for a specific chain
     * @param chain The chain identifier (e.g., "sepolia", "arbitrum_sepolia")
     * @param fieldName The field name to update (e.g., "iexecLayerZeroBridgeAddress")
     * @param value The address value to set
     * @param configPath The path to the config file
     */
    function updateConfigAddress(string memory chain, string memory fieldName, address value, string memory configPath) internal {
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
        
        console.log("Updated config.json:");
        console.log("   Chain:", chain);
        console.log("   Field:", fieldName);
        console.log("   Address:", addressString);
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
            console.log("Added newline to EOF in config file");
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
