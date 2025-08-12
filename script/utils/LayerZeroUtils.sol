// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {LzConfig} from "../lib/ConfigLib.sol";

// TODO move script/lib/* utility files in this folder.
library LayerZeroUtils {
    using OptionsBuilder for bytes;

    uint16 constant LZ_RECEIVE_MESSAGE_TYPE = 1; // lzReceive()
    uint16 constant LZ_COMPOSE_MESSAGE_TYPE = 2; // lzCompose()
    uint16 constant EXECUTOR_CONFIG_TYPE = 1;
    uint16 constant ULN_CONFIG_TYPE = 2;
    uint16 constant RECEIVE_CONFIG_TYPE = 2;

    /**
     * Builds the LayerZero receive configuration for the executor.
     * @param gasLimit The gas limit for the lzReceive() function.
     * @param value The msg.value for the lzReceive() function.
     */
    function buildLzReceiveExecutorConfig(uint128 gasLimit, uint128 value) public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit, value);
    }

    /**
     * Gets the on-chain enforced options for `lzReceive()`.
     * @param bridge The LayerZero bridge contract.
     * @param endpointId The LayerZero endpoint ID of the target chain.
     */
    function getOnchainLzReceiveEnforcedOptions(IexecLayerZeroBridge bridge, uint32 endpointId)
        public
        view
        returns (bytes memory)
    {
        return bridge.enforcedOptions(endpointId, LZ_RECEIVE_MESSAGE_TYPE);
    }

    /**
     * Gets the on-chain enforced options for `lzCompose()`.
     * @param bridge The LayerZero bridge contract.
     * @param endpointId The LayerZero endpoint ID of the target chain.
     */
    function getOnchainLzComposeEnforcedOptions(IexecLayerZeroBridge bridge, uint32 endpointId)
        public
        view
        returns (bytes memory)
    {
        return bridge.enforcedOptions(endpointId, LZ_COMPOSE_MESSAGE_TYPE);
    }

    /**
     * Checks if the on-chain options for the bridge match the provided options for the target chain.
     * @param bridge The source bridge contract.
     * @param endpointId The LayerZero endpoint ID of the target chain.
     * @param options The options to compare against.
     */
    function matchesOnchainEnforcedOptions(IexecLayerZeroBridge bridge, uint32 endpointId, bytes memory options)
        public
        view
        returns (bool)
    {
        bytes memory lzReceiveOnchainOptions = getOnchainLzReceiveEnforcedOptions(bridge, endpointId);
        bytes memory lzComposeOnchainOptions = getOnchainLzComposeEnforcedOptions(bridge, endpointId);
        return keccak256(lzReceiveOnchainOptions) == keccak256(options)
            && keccak256(lzComposeOnchainOptions) == keccak256(options);
    }

    /**
     * Builds the enforced options for a LayerZero bridge.
     * @param targetEndpointId The LayerZero endpoint ID of the receiving chain.
     * @param options The options to enforce.
     */
    function buildEnforcedOptions(uint32 targetEndpointId, bytes memory options)
        public
        pure
        returns (EnforcedOptionParam[] memory)
    {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam(targetEndpointId, LZ_RECEIVE_MESSAGE_TYPE, options);
        enforcedOptions[1] = EnforcedOptionParam(targetEndpointId, LZ_COMPOSE_MESSAGE_TYPE, options);
        return enforcedOptions;
    }

    /**
     * Gets the bridge current configuration.
     * @dev Values of the default configuration defined by LayerZero can be found here:
     *   - https://docs.layerzero.network/v2/deployments/deployed-contracts
     *   - https://layerzeroscan.com/tools/defaults
     * @dev see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
     * @param endpoint The LayerZero endpoint contract address.
     * @param bridge The LayerZero bridge contract address.
     * @param eid The LayerZero endpoint ID.
     */
    function getBridgeConfig(
        ILayerZeroEndpointV2 endpoint,
        address bridge,
        uint32 eid
    ) public view returns (address, address, ExecutorConfig memory, UlnConfig memory) {
        // Get libraries.
        address sendLibrary = endpoint.getSendLibrary(bridge, eid);
        (address receiveLibrary,) = endpoint.getReceiveLibrary(bridge, eid);
        bytes memory config;
        // Get executor config.
        config = endpoint.getConfig(bridge, sendLibrary, eid, EXECUTOR_CONFIG_TYPE);
        ExecutorConfig memory execConfig = abi.decode(config, (ExecutorConfig));
        // Get ULN config.
        config = endpoint.getConfig(bridge, sendLibrary, eid, ULN_CONFIG_TYPE);
        UlnConfig memory ulnConfig = abi.decode(config, (UlnConfig));
        return (sendLibrary, receiveLibrary, execConfig, ulnConfig);
    }

    /**
     * Sets the send and receive config on the source chain. First, set the config of send
     * operations targeting the destination chain then set the config of the receive operations
     * for requests coming from the destination chain.
     * Send configuration includes:
     * - Send library address.
     * - Receive library address.
     * - Executor config.
     * - ULN config.
     * Receive configuration includes:
     * - Only ULN config.
     * Note: ULNConfig defines security parameters (DVNs + confirmation threshold).
     * @dev see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
     * @param srcChainConfig The LayerZero configuration parameters for the source chain.
     * @param dstChainConfig The LayerZero configuration parameters for the destination chain.
     */
    function setBridgeConfig(
        LzConfig memory srcChainConfig,
        LzConfig memory dstChainConfig
    ) public {
        // Replace 0s with NIL values.
        _sanitizeZeroValues(srcChainConfig);
        _sanitizeZeroValues(dstChainConfig);
        //
        // Set the send config for the destination chain (eid).
        //
        ILayerZeroEndpointV2 endpoint = ILayerZeroEndpointV2(srcChainConfig.endpoint);
        // Set the send and receive libraries.
        uint256 gracePeriod = 0;
        endpoint.setSendLibrary(srcChainConfig.bridge, dstChainConfig.endpointId, srcChainConfig.sendLibrary);
        endpoint.setReceiveLibrary(srcChainConfig.bridge, dstChainConfig.endpointId, srcChainConfig.receiveLibrary, gracePeriod);
        // Set the executor and ULN config.
        bytes memory encodedExecutorConfig = abi.encode(srcChainConfig.executorConfig);
        // ULNConfig defines security parameters (DVNs + confirmation threshold)
        bytes memory encodedUlnConfig  = abi.encode(srcChainConfig.ulnConfig);
        SetConfigParam[] memory sendParams = new SetConfigParam[](2);
        // ExecutorConfig sets max bytes per cross-chain message & the address that pays destination execution fees
        sendParams[0] = SetConfigParam(dstChainConfig.endpointId, EXECUTOR_CONFIG_TYPE, encodedExecutorConfig);
        sendParams[1] = SetConfigParam(dstChainConfig.endpointId, ULN_CONFIG_TYPE, encodedUlnConfig);
        endpoint.setConfig(srcChainConfig.bridge, srcChainConfig.sendLibrary, sendParams);
        //
        // Set only the receive config for requests in the opposite direction (coming from the destination chain).
        //
        /// @dev note that the receive config must match the send config on the opposite chain.
        SetConfigParam[] memory receiveParams = new SetConfigParam[](1);
        receiveParams[0] = SetConfigParam(dstChainConfig.endpointId, RECEIVE_CONFIG_TYPE, abi.encode(dstChainConfig.ulnConfig));
        endpoint.setConfig(dstChainConfig.bridge, dstChainConfig.receiveLibrary, receiveParams);
    }

    /**
     * Sanitizes the zero values in the LayerZero configuration by replacing
     * them with NIL values because 0 values will be interpretted as defaults.
     * To apply NIL settings, use:
     *   - uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
     *   - uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
     * @dev see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
     * @param chainConfig The LayerZero configuration to sanitize.
     */
    function _sanitizeZeroValues(LzConfig memory chainConfig) private pure {
        uint8 NIL_DVN_COUNT = type(uint8).max;
        uint64 NIL_CONFIRMATIONS = type(uint64).max;
        if (chainConfig.ulnConfig.confirmations == 0) {
            chainConfig.ulnConfig.confirmations = NIL_CONFIRMATIONS;
        }
        if (chainConfig.ulnConfig.requiredDVNCount == 0) {
            chainConfig.ulnConfig.requiredDVNCount = NIL_DVN_COUNT;
        }
        if (chainConfig.ulnConfig.optionalDVNCount == 0) {
            chainConfig.ulnConfig.optionalDVNCount = NIL_DVN_COUNT;
        }
        if (chainConfig.ulnConfig.optionalDVNThreshold == 0) {
            chainConfig.ulnConfig.optionalDVNThreshold = NIL_DVN_COUNT;
        }
    }
}
