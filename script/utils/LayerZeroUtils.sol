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
     * Sets the send config on the source chain. Configuration includes:
     * - Send library address.
     * - Receive library address.
     * - Executor config.
     * - ULN config.
     * Note:
     * - ULNConfig defines security parameters (DVNs + confirmation threshold).
     * - 0 values will be interpretted as defaults, so to apply NIL settings, use:
     *      - uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
     *      - uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
     * @dev see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
     * @param endpoint The LayerZero endpoint contract on the source (sending) chain.
     * @param destinationEid The LayerZero endpoint ID of the destination (receiving) chain.
     * @param bridge The LayerZero bridge contract on the source (sending) chain.
     * @param sendLibrary The send library address.
     * @param receiveLibrary The receive library address.
     * @param executorConfig The executor config to set.
     * @param ulnConfig The ULN config to set.
     */
    function setBridgeSendConfig(
        ILayerZeroEndpointV2 endpoint,
        uint32 destinationEid,
        address bridge,
        address sendLibrary,
        address receiveLibrary,
        ExecutorConfig memory executorConfig,
        UlnConfig memory ulnConfig
    ) public returns (bool) {
        endpoint.setSendLibrary(bridge, destinationEid, sendLibrary);
        endpoint.setReceiveLibrary(bridge, destinationEid, receiveLibrary, 0);
        bytes memory encodedExecutorConfig = abi.encode(executorConfig);
        bytes memory encodedUlnConfig  = abi.encode(ulnConfig);
        SetConfigParam[] memory sendParams = new SetConfigParam[](2);
        sendParams[0] = SetConfigParam(destinationEid, EXECUTOR_CONFIG_TYPE, encodedExecutorConfig);
        sendParams[1] = SetConfigParam(destinationEid, ULN_CONFIG_TYPE, encodedUlnConfig);
        endpoint.setConfig(bridge, sendLibrary, sendParams);
        return true;
    }

    /**
     * Sets the receive config on the destination chain. It only sets the ULN config.
     * Note:
     * - ULNConfig defines security parameters (DVNs + confirmation threshold).
     * - 0 values will be interpretted as defaults, so to apply NIL settings, use:
     *      - uint8 internal constant NIL_DVN_COUNT = type(uint8).max;
     *      - uint64 internal constant NIL_CONFIRMATIONS = type(uint64).max;
     * @dev see https://docs.layerzero.network/v2/developers/evm/configuration/dvn-executor-config
     * @param endpoint The LayerZero endpoint contract on the destination (receiving) chain.
     * @param sourceEid The LayerZero endpoint ID of the source (sending) chain.
     * @param bridge The LayerZero bridge contract on the destination (receiving) chain.
     * @param receiveLibrary The receive library address.
     * @param ulnConfig The ULN config to set.
     */
    function setBridgeReceiveConfig(
        ILayerZeroEndpointV2 endpoint,
        uint32 sourceEid,
        address bridge,
        address receiveLibrary,
        UlnConfig memory ulnConfig
    ) public {
        bytes memory encodedUlnConfig  = abi.encode(ulnConfig);
        SetConfigParam[] memory receiveParams = new SetConfigParam[](1);
        receiveParams[0] = SetConfigParam(sourceEid, RECEIVE_CONFIG_TYPE, encodedUlnConfig);
        ILayerZeroEndpointV2(endpoint).setConfig(bridge, receiveLibrary, receiveParams);
    }
}
