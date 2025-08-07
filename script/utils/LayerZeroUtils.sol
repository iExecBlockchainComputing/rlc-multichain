// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {Vm} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {IexecLayerZeroBridge} from "../../src/bridges/layerZero/IexecLayerZeroBridge.sol";

// TODO move script/lib/* utility files in this folder.
library LayerZeroUtils {
    using OptionsBuilder for bytes;

    // // forge-fmt: off
    // uint16 lzReceiveMessageType = 1; // lzReceive()
    // uint16 lzComposeMessageType = 2; // lzCompose()
    // // forge-fmt: on
    uint16 constant LZ_RECEIVE_MESSAGE_TYPE = 1; // lzReceive()
    uint16 constant LZ_COMPOSE_MESSAGE_TYPE = 2; // lzCompose()

    /**
     * Builds the LayerZero receive configuration for the executor.
     * @param gasLimit The gas limit for the lzReceive() function.
     * @param value The msg.value for the lzReceive() function.
     */
    function buildLzReceiveExecutorConfig(uint128 gasLimit, uint128 value) public pure returns (bytes memory) {
        return OptionsBuilder.newOptions().addExecutorLzReceiveOption(gasLimit, value);
    }

    /**
     * Checks if the on-chain options for the source bridge match the provided options.
     * @param sourceBridge The source bridge contract.
     * @param targetEndpointId The LayerZero endpoint ID of the target bridge.
     * @param options The options to compare against.
     */
    function matchesOnchainOptions(
        IexecLayerZeroBridge sourceBridge,
        uint32 targetEndpointId,
        bytes memory options
    ) public view returns (bool) {
        bytes memory lzReceiveOnchainOptions = sourceBridge.enforcedOptions(targetEndpointId, LZ_RECEIVE_MESSAGE_TYPE);
        bytes memory lzComposeOnchainOptions = sourceBridge.enforcedOptions(targetEndpointId, LZ_COMPOSE_MESSAGE_TYPE);
        return keccak256(lzReceiveOnchainOptions) != keccak256(options)
                || keccak256(lzComposeOnchainOptions) != keccak256(options);
    }

    /**
     * Builds the enforced options for a LayerZero bridge.
     * @param targetEndpointId The LayerZero endpoint ID of the receiving chain.
     * @param options The options to enforce.
     */
    function buildEnforcedOptions(uint32 targetEndpointId, bytes memory options) public pure returns (EnforcedOptionParam[] memory) {
        EnforcedOptionParam[] memory enforcedOptions = new EnforcedOptionParam[](2);
        enforcedOptions[0] = EnforcedOptionParam(targetEndpointId, LZ_RECEIVE_MESSAGE_TYPE, options);
        enforcedOptions[1] = EnforcedOptionParam(targetEndpointId, LZ_COMPOSE_MESSAGE_TYPE, options);
        return enforcedOptions;
    }
}
