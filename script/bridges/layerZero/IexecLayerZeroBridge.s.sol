// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {UlnConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/uln/UlnBase.sol";
import {ExecutorConfig} from "@layerzerolabs/lz-evm-messagelib-v2/contracts/SendLibBase.sol";
import {SetConfigParam} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessageLibManager.sol";
import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {ConfigLib} from "./../../lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";
import {LayerZeroUtils} from "../../utils/LayerZeroUtils.sol";
import {LzConfig} from "../../lib/ConfigLib.sol";

/**
 * A script to deploy and initialize the IexecLayerZeroBridge contract.
 * It uses CreateX to deploy the contract as a UUPS proxy.
 */
contract Deploy is Script {
    /**
     * Reads configuration from config file and deploys `IexecLayerZeroBridge` contract.
     * @dev This function is called by `forge script run`.
     * @return address of the deployed `IexecLayerZeroBridge` proxy contract.
     */
    function run() external returns (address) {
        string memory chain = vm.envString("CHAIN");
        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(chain);

        vm.startBroadcast();
        address iexecLayerZeroBridgeProxy = deploy(
            params.approvalRequired,
            params.approvalRequired ? params.rlcLiquidityUnifierAddress : params.rlcCrosschainTokenAddress,
            params.lzEndpoint,
            params.initialAdmin,
            params.initialUpgrader,
            params.initialPauser,
            params.createxFactory,
            params.iexecLayerZeroBridgeCreatexSalt
        );

        vm.stopBroadcast();
        ConfigLib.updateConfigAddress(chain, "iexecLayerZeroBridgeAddress", iexecLayerZeroBridgeProxy);
        return iexecLayerZeroBridgeProxy;
    }

    function deploy(
        bool approvalRequired,
        address bridgeableToken,
        address lzEndpoint,
        address initialAdmin,
        address initialUpgrader,
        address initialPauser,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory constructorData = abi.encode(approvalRequired, bridgeableToken, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(
            IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
        );
        return UUPSProxyDeployer.deployUsingCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createxFactory, createxSalt
        );
    }
}

/**
 * A script to configure the IexecLayerZeroBridge contract:
 * - Set the peer for the bridge (`setPeer`).
 * - Set enforced options for the bridge (`setEnforcedOptions`).
 * - Set DVNs config for the bridge (`setDvnConfig`). TODO
 * - Authorize the bridge in RLCLiquidityUnifier or RLCCrosschainToken contract (`grantRole`).
 * The script should be called at least once for each chain where the bridge is configured.
 */
contract Configure is Script {
    using OptionsBuilder for bytes;

    /**
     * Reads configuration from config file and configures `IexecLayerZeroBridge` contract.
     * @dev This function is called by `forge script run`.
     */
    function run() external {
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");
        ConfigLib.CommonConfigParams memory sourceParams = ConfigLib.readCommonConfig(sourceChain);
        ConfigLib.CommonConfigParams memory targetParams = ConfigLib.readCommonConfig(targetChain);
        LzConfig memory srcChainLzConfig = ConfigLib.readLzConfig(sourceChain);
        LzConfig memory dstChainLzConfig = ConfigLib.readLzConfig(targetChain);
        console.log("Configuring bridge [chain:%s, address:%s]", sourceChain, sourceParams.iexecLayerZeroBridgeAddress);
        vm.startBroadcast();
        configure(sourceParams, targetParams, srcChainLzConfig, dstChainLzConfig);
        vm.stopBroadcast();
    }

    /**
     * Setup bridge configuration.
     * @param sourceParams Configuration parameters for the source chain.
     * @param targetParams Configuration parameters for the target chain.
     * @return true if at least one configuration was changed, false otherwise.
     */
    function configure(
        ConfigLib.CommonConfigParams memory sourceParams,
        ConfigLib.CommonConfigParams memory targetParams,
        LzConfig memory srcChainLzConfig,
        LzConfig memory dstChainLzConfig
    ) public returns (bool) {
        address bridge = sourceParams.iexecLayerZeroBridgeAddress;
        RLCLiquidityUnifier rlcLiquidityUnifier = RLCLiquidityUnifier(sourceParams.rlcLiquidityUnifierAddress);
        RLCCrosschainToken rlcCrosschainToken = RLCCrosschainToken(sourceParams.rlcCrosschainTokenAddress);
        bool bool1 = setBridgePeerIfNeeded(bridge, targetParams.lzEndpointId, targetParams.iexecLayerZeroBridgeAddress);
        bool bool2 = setEnforcedOptionsIfNeeded(bridge, targetParams.lzEndpointId);
        bool bool3 = setExecutorAndUlnConfigIfNeeded(srcChainLzConfig, dstChainLzConfig);
        bool bool4 = authorizeBridgeIfNeeded(
            bridge,
            sourceParams.approvalRequired ? address(rlcLiquidityUnifier) : address(rlcCrosschainToken),
            sourceParams.approvalRequired
                ? rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE()
                : rlcCrosschainToken.TOKEN_BRIDGE_ROLE()
        );
        return bool1 || bool2 || bool3 || bool4;
    }

    /**
     * Sets the bridge peer if it is not already set. Otherwise, do nothing.
     * @dev see https://docs.layerzero.network/v2/developers/evm/technical-reference/integration-checklist#call-setpeer-on-every-oapp-deployment
     * @param bridgeAddress The address of the LayerZero bridge contract.
     * @param targetEndpointId The ID of the target LayerZero endpoint.
     * @param targetBridgeAddress The address of the target LayerZero bridge contract.
     */
    function setBridgePeerIfNeeded(address bridgeAddress, uint32 targetEndpointId, address targetBridgeAddress)
        public
        returns (bool)
    {
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(bridgeAddress);
        bytes32 peer = bytes32(uint256(uint160(targetBridgeAddress)));
        if (bridge.isPeer(targetEndpointId, peer)) {
            console.log(
                "Bridge peer already set [endpointId:%s, peer:%s]", vm.toString(targetEndpointId), vm.toString(peer)
            );
            return false;
        }
        console.log("Setting bridge peer [endpointId:%s, peer:%s]", vm.toString(targetEndpointId), vm.toString(peer));
        bridge.setPeer(targetEndpointId, peer);
        return true;
    }

    /**
     * Sets the enforced options for the LayerZero bridge if they are not already set.
     * If the same options are already enforced on-chain, do nothing.
     * @dev see https://docs.layerzero.network/v2/developers/evm/technical-reference/integration-checklist#implement-enforced-options
     * @param bridgeAddress The address of the LayerZero bridge contract.
     * @param targetEndpointId The ID of the target LayerZero endpoint.
     */
    function setEnforcedOptionsIfNeeded(address bridgeAddress, uint32 targetEndpointId) public returns (bool) {
        IexecLayerZeroBridge bridge = IexecLayerZeroBridge(bridgeAddress);
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        if (LayerZeroUtils.matchesOnchainEnforcedOptions(bridge, targetEndpointId, options)) {
            console.log(
                "Bridge enforced options already set [endpointId:%s, options:%s]",
                vm.toString(targetEndpointId),
                vm.toString(options)
            );
            return false;
        }
        EnforcedOptionParam[] memory enforcedOptions = LayerZeroUtils.buildEnforcedOptions(targetEndpointId, options);
        console.log(
            "Setting bridge enforced options [endpointId:%s, options:%s]",
            vm.toString(targetEndpointId),
            vm.toString(options)
        );
        bridge.setEnforcedOptions(enforcedOptions);
        return true;
    }

    // TODO use LayerZero CLI:
    // https://docs.layerzero.network/v2/get-started/create-lz-oapp/configuring-pathways
    // More on DVNs https://docs.layerzero.network/v2/concepts/modular-security/security-stack-dvns
    function setExecutorAndUlnConfigIfNeeded(
        LzConfig memory srcChainLzConfig,
        LzConfig memory dstChainLzConfig
    ) public returns (bool) {
        LayerZeroUtils.setBridgeConfig(srcChainLzConfig, dstChainLzConfig);
        return true;
    }

    /**
     * Authorizes the bridge in the RLCLiquidityUnifier or RLCCrosschainToken contract if it
     * is not already authorized. Otherwise, do nothing.
     * @param bridge The address of the LayerZero bridge contract.
     * @param authorizerAddress The address of the authorizer contract.
     * @param roleId The role ID to grant to the bridge.
     */
    function authorizeBridgeIfNeeded(address bridge, address authorizerAddress, bytes32 roleId) public returns (bool) {
        IAccessControl authorizer = IAccessControl(authorizerAddress);
        if (authorizer.hasRole(roleId, bridge)) {
            console.log("Bridge already authorized");
            return false;
        }
        console.log("Granting bridge role in contract", authorizerAddress);
        authorizer.grantRole(roleId, bridge);
        return true;
    }
}

/**
 * A script to upgrade the IexecLayerZeroBridge contract.
 */
contract Upgrade is Script {
    function run() external {
        string memory chain = vm.envString("CHAIN");
        ConfigLib.CommonConfigParams memory commonParams = ConfigLib.readCommonConfig(chain);

        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;
        address bridgeableToken = commonParams.approvalRequired
            ? commonParams.rlcLiquidityUnifierAddress
            : commonParams.rlcCrosschainTokenAddress;
        vm.startBroadcast();
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: commonParams.iexecLayerZeroBridgeAddress,
            constructorData: abi.encode(commonParams.approvalRequired, bridgeableToken, commonParams.lzEndpoint),
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2", // Would be production contract in real deployment
            newStateVariable: newStateVariable
        });
        UpgradeUtils.executeUpgrade(params);
        vm.stopBroadcast();
    }
}
