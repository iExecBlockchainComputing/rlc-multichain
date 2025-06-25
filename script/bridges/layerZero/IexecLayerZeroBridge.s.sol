// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import "forge-std/StdJson.sol";
import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {BridgeConfigLib} from "./BridgeConfigLib.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "../../lib/UpdateEnvUtils.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";

contract Deploy is Script {
    using stdJson for string;

    function run() external returns (address) {
        vm.startBroadcast();

        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        BridgeConfigLib.CommonConfigParams memory params = BridgeConfigLib.readCommonConfig(config, chain);

        address iexecLayerZeroBridgeProxy = deploy(
            params.bridgeableToken,
            params.lzEndpoint,
            params.initialAdmin,
            params.initialUpgrader,
            params.initialPauser,
            params.createxFactory,
            params.createxSalt
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
    using stdJson for string;

    function run() external {
        string memory config = vm.readFile("config/config.json");
        string memory sourceChain = vm.envString("SOURCE_CHAIN");
        string memory targetChain = vm.envString("TARGET_CHAIN");

        vm.startBroadcast();

        BridgeConfigLib.CommonConfigParams memory sourceParams = BridgeConfigLib.readCommonConfig(config, sourceChain);
        BridgeConfigLib.CommonConfigParams memory targetParams = BridgeConfigLib.readCommonConfig(config, targetChain);

        // Configure one bridge to another
        IexecLayerZeroBridge sourceBridge = IexecLayerZeroBridge(sourceParams.bridgeAddress);
        sourceBridge.setPeer(targetParams.layerZeroChainId, bytes32(uint256(uint160(targetParams.bridgeAddress))));

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    using stdJson for string;

    function run() external {
        vm.startBroadcast();

        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        BridgeConfigLib.CommonConfigParams memory commonParams = BridgeConfigLib.readCommonConfig(config, chain);
        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: commonParams.bridgeAddress,
            rlcToken: commonParams.bridgeableToken,
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2", // Would be production contract in real deployment
            lzEndpoint: commonParams.lzEndpoint,
            newStateVariable: newStateVariable,
            validateOnly: false
        });

        address newImplementationAddress = UpgradeUtils.executeUpgrade(params);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    using stdJson for string;

    function run() external {
        string memory config = vm.readFile("config/config.json");
        string memory chain = vm.envString("CHAIN");

        BridgeConfigLib.CommonConfigParams memory commonParams = BridgeConfigLib.readCommonConfig(config, chain);

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0), // Not needed for validation
            lzEndpoint: commonParams.lzEndpoint,
            rlcToken: commonParams.bridgeableToken,
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2",
            newStateVariable: 1000000 * 10 ** 9,
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
