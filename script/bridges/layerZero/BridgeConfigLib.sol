// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";

/**
 * @title BridgeConfigLib
 * @dev Library for handling bridge configuration logic
 */
library BridgeConfigLib {
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
        address bridgeableToken;
        address bridgeAddress;
    }

    /**
     * @dev Gets the appropriate bridgeable token address based on the chain
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
        params.lzEndpoint = config.readAddress(string.concat(prefix, ".layerZeroEndpointAddress"));
        params.createxSalt = config.readBytes32(string.concat(prefix, ".iexecLayerZeroBridgeCreatexSalt"));
        params.bridgeAddress = config.readAddress(string.concat(prefix, ".iexecLayerZeroBridgeAddress"));
        params.layerZeroChainId = uint32(config.readUint(string.concat(prefix, ".layerZeroChainId")));
    }
}
