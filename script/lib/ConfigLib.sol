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
        address lzEndpoint;
        uint32 lzChainId;
        address rlcToken; // RLC token address (already deployed on L1)
        bytes32 rlcLiquidityUnifierCreatexSalt; // Salt for CreateX deployment of the RLC Liquidity Unifier
        address rlcLiquidityUnifierAddress; // RLC Liquidity Unifier address (only on L1)
        bytes32 rlcCrossChainTokenCreatexSalt; // Salt for CreateX deployment of the RLC CrossChain Token
        address rlcCrossChainTokenAddress; // RLC CrossChain token address (only on L2)
        bool approvalRequired; // Whether approval is required for the bridgeable token (yes on L1, no on L2)
        bytes32 iexecLayerZeroBridgeCreatexSalt; // Salt for CreateX deployment of the LayerZero bridge
        address iexecLayerZeroBridgeAddress;
    }

    /**
     * @dev Gets the appropriate bridgeable token address based on the chain
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the bridgeable token (RLCLiquidityUnifier on mainnet, RLC CrossChain on L2s)
     */
    function getLiquidityUnifierAddress(string memory config, string memory prefix) internal pure returns (address) {
        if (config.readBool(string.concat(prefix, ".approvalRequired"))) {
            return config.readAddress(string.concat(prefix, ".rlcLiquidityUnifierAddress"));
        } else {
            return address(0);
        }
    }
    /**
     * @dev Gets the RLC CrossChain token address based on the chain
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the RLC CrossChain token
     */

    function getRLCCrossChainTokenAddress(string memory config, string memory prefix) internal pure returns (address) {
        if (config.readBool(string.concat(prefix, ".approvalRequired"))) {
            return address(0);
        } else {
            return config.readAddress(string.concat(prefix, ".rlcCrossChainTokenAddress"));
        }
    }

    /**
     * @dev Gets the bridgeable token address based on the chains
     * @param config The JSON configuration string
     * @param prefix The JSON path prefix for the current chain
     * @return The address of the RLC token (native RLC on L1, crosschain token on L2s)
     */
    function getRLCTokenAddress(string memory config, string memory prefix) internal pure returns (address) {
        if (config.readBool(string.concat(prefix, ".approvalRequired"))) {
            return config.readAddress(string.concat(prefix, ".rlcAddress"));
        } else {
            return address(0);
        }
    }

    function getAllCreatexParams(string memory config, string memory prefix)
        internal
        pure
        returns (
            bytes32 rlcCrossChainTokenCreatexSalt,
            bytes32 rlcLiquidityUnifierCreatexSalt,
            bytes32 iexecLayerZeroBridgeCreatexSalt
        )
    {
        if (config.readBool(string.concat(prefix, ".approvalRequired"))) {
            rlcCrossChainTokenCreatexSalt = bytes32(0); // RLC CrossChain token is not deployed on L1
            iexecLayerZeroBridgeCreatexSalt =
                config.readBytes32(string.concat(prefix, ".iexecLayerZeroBridgeCreatexSalt"));
            rlcLiquidityUnifierCreatexSalt =
                config.readBytes32(string.concat(prefix, ".rlcLiquidityUnifierCreatexSalt"));
        } else {
            rlcCrossChainTokenCreatexSalt = config.readBytes32(string.concat(prefix, ".rlcCrossChainTokenCreatexSalt"));
            rlcLiquidityUnifierCreatexSalt = bytes32(0); // RLC Liquidity Unifier is not deployed on L2s
            iexecLayerZeroBridgeCreatexSalt =
                config.readBytes32(string.concat(prefix, ".iexecLayerZeroBridgeCreatexSalt"));
        }
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
        params.rlcToken = getRLCTokenAddress(config, prefix);
        (
            params.rlcCrossChainTokenCreatexSalt,
            params.rlcLiquidityUnifierCreatexSalt,
            params.iexecLayerZeroBridgeCreatexSalt
        ) = getAllCreatexParams(config, prefix);
        params.rlcCrossChainTokenAddress = getRLCCrossChainTokenAddress(config, prefix);
        params.rlcLiquidityUnifierAddress = getLiquidityUnifierAddress(config, prefix);
        params.approvalRequired = config.readBool(string.concat(prefix, ".approvalRequired"));
        params.iexecLayerZeroBridgeAddress = config.readAddress(string.concat(prefix, ".iexecLayerZeroBridgeAddress"));
        params.lzEndpoint = config.readAddress(string.concat(prefix, ".lzEndpointAddress"));
        params.lzChainId = uint32(config.readUint(string.concat(prefix, ".lzChainId")));
    }
}
