// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

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
        string chainName;
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
