// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {ConfigLib} from "./../../lib/ConfigLib.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "../../lib/UpdateEnvUtils.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        ConfigLib.CommonConfigParams memory params = ConfigLib.readCommonConfig(config, chain);

        address iexecLayerZeroBridgeProxy = deploy(
            params.approvalRequired ? params.rlcLiquidityUnifier : params.rlcCrossChainToken,
            params.lzEndpoint,
            params.initialAdmin,
            params.initialUpgrader,
            params.initialPauser,
            params.createxFactory,
            params.createxBridgeSalt
        );

        vm.stopBroadcast();

        address implementationAddress = Upgrades.getImplementationAddress(iexecLayerZeroBridgeProxy);
        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS", implementationAddress);
        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_PROXY_ADDRESS", iexecLayerZeroBridgeProxy);
        return iexecLayerZeroBridgeProxy;
    }

    function deploy(
        address bridgeableToken,
        address lzEndpoint,
        address initialAdmin,
        address initialUpgrader,
        address initialPauser,
        address createxFactory,
        bytes32 createxSalt
    ) public returns (address) {
        bytes memory constructorData = abi.encode(bridgeableToken, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(
            IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
        );
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createxFactory, createxSalt
        );
    }
}

contract Configure is Script {
    function run() external {
        string memory config = vm.readFile("config/config.json");
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");

        ConfigLib.CommonConfigParams memory sourceParams = ConfigLib.readCommonConfig(config, sourceChain);
        ConfigLib.CommonConfigParams memory targetParams = ConfigLib.readCommonConfig(config, targetChain);
        vm.startBroadcast();

        IexecLayerZeroBridge sourceBridge = IexecLayerZeroBridge(sourceParams.layerZeroBridge);
        sourceBridge.setPeer(targetParams.lzChainId, bytes32(uint256(uint160(targetParams.layerZeroBridge))));

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        ConfigLib.CommonConfigParams memory commonParams = ConfigLib.readCommonConfig(config, chain);
        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;

        address bridgeableToken =
            commonParams.approvalRequired ? commonParams.rlcLiquidityUnifier : commonParams.rlcCrossChainToken;
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: commonParams.layerZeroBridge,
            constructorData: abi.encode(bridgeableToken, commonParams.lzEndpoint),
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2", // Would be production contract in real deployment
            newStateVariable: newStateVariable,
            validateOnly: false
        });

        address newImplementationAddress = UpgradeUtils.executeUpgrade(params);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {
        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        ConfigLib.CommonConfigParams memory commonParams = ConfigLib.readCommonConfig(config, chain);
        address bridgeableToken =
            commonParams.approvalRequired ? commonParams.rlcLiquidityUnifier : commonParams.rlcCrossChainToken;
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0),
            constructorData: abi.encode(bridgeableToken, commonParams.lzEndpoint),
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2",
            newStateVariable: 1000000 * 10 ** 9,
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
