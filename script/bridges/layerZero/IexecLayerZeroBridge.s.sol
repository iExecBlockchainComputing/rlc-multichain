// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {EnforcedOptionParam} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OAppOptionsType3.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {ConfigLib} from "./../../lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {RLCLiquidityUnifier} from "../../../src/RLCLiquidityUnifier.sol";
import {RLCCrosschainToken} from "../../../src/RLCCrosschainToken.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";
import {LayerZeroUtils} from "../../utils/LayerZeroUtils.sol";

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
 * - Set the peer for the source bridge (`setPeer`).
 * - Set enforced options for the source bridge (`setEnforcedOptions`).
 * - Set DVNs config for the source bridge (`setDvnConfig`).
 * - Authorize the source bridge in RLCLiquidityUnifier or RLCCrosschainToken
 *   contract (`grantRole`).
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
        vm.startBroadcast();
        configure(sourceParams, targetParams);
        vm.stopBroadcast();
    }

    /**
     * Setup bridge configuration.
     * @param sourceParams Common configuration parameters for the source chain.
     * @param targetParams Common configuration parameters for the target chain.
     * @return true if the configuration was successful.
     */
    // TODO split into smaller functions.
    function configure(
        ConfigLib.CommonConfigParams memory sourceParams,
        ConfigLib.CommonConfigParams memory targetParams
    ) public returns (bool) {
        bool configured;
        IexecLayerZeroBridge sourceBridge = IexecLayerZeroBridge(sourceParams.iexecLayerZeroBridgeAddress);
        console.log("Configuring bridge [address:%s]", address(sourceBridge));
        //
        // Set peer for the source bridge if not already set.
        //
        bytes32 peer = bytes32(uint256(uint160(targetParams.iexecLayerZeroBridgeAddress)));
        if (!sourceBridge.isPeer(targetParams.lzEndpointId, peer)) {
            console.log(
                "Setting bridge peer [endpointId:%s, peer:%s]",
                vm.toString(targetParams.lzEndpointId),
                vm.toString(peer)
            );
            sourceBridge.setPeer(targetParams.lzEndpointId, peer);
            configured = true;
        }
        //
        // Set enforced options for the source bridge if not already set.
        //
        bytes memory options = LayerZeroUtils.buildLzReceiveExecutorConfig(90_000, 0);
        if (!LayerZeroUtils.matchesOnchainOptions(sourceBridge, targetParams.lzEndpointId, options)) {
            EnforcedOptionParam[] memory enforcedOptions =
                LayerZeroUtils.buildEnforcedOptions(targetParams.lzEndpointId, options);
            console.log(
                "Setting bridge enforced options [endpointId:%s, options:%s]",
                vm.toString(targetParams.lzEndpointId),
                vm.toString(options)
            );
            sourceBridge.setEnforcedOptions(enforcedOptions);
            configured = true;
        }
        // Authorize bridge in the relevant contract.
        // TODO don't send grant tx if the bridge is already authorized.
        if (sourceParams.approvalRequired) {
            console.log("Granting TOKEN_BRIDGE_ROLE to bridge in RLCLiquidityUnifier");
            RLCLiquidityUnifier rlcLiquidityUnifier = RLCLiquidityUnifier(sourceParams.rlcLiquidityUnifierAddress);
            bytes32 bridgeTokenRoleId = rlcLiquidityUnifier.TOKEN_BRIDGE_ROLE();
            rlcLiquidityUnifier.grantRole(bridgeTokenRoleId, address(sourceBridge));
            configured = true;
        } else {
            console.log("Granting TOKEN_BRIDGE_ROLE to bridge in RLCCrosschainToken");
            RLCCrosschainToken rlcCrosschainToken = RLCCrosschainToken(sourceParams.rlcCrosschainTokenAddress);
            bytes32 bridgeTokenRoleId = rlcCrosschainToken.TOKEN_BRIDGE_ROLE();
            rlcCrosschainToken.grantRole(bridgeTokenRoleId, address(sourceBridge));
            configured = true;
        }
        return configured;
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
