// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {IexecLayerZeroBridge} from "../../../src/bridges/layerZero/IexecLayerZeroBridge.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "../../lib/UpdateEnvUtils.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        //TODO migrate to read from config file and split deployment based on chain target.
        address rlcCrosschain = vm.envAddress("RLC_CROSSCHAIN_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address initialAdmin = vm.envAddress("ADMIN_ADDRESS");
        address initialUpgrader = vm.envAddress("UPGRADER_ADDRESS");
        address initialPauser = vm.envAddress("PAUSER_ADDRESS");
        bytes32 createxSalt = vm.envBytes32("SALT");

        address iexecLayerZeroBridgeProxy =
            deploy(rlcCrosschain, lzEndpoint, initialAdmin, initialUpgrader, initialPauser, createxSalt);

        vm.stopBroadcast();

        address implementationAddress = Upgrades.getImplementationAddress(iexecLayerZeroBridgeProxy);
        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS", implementationAddress);
        EnvUtils.updateEnvVariable("LAYERZERO_BRIDGE_PROXY_ADDRESS", iexecLayerZeroBridgeProxy);
        return iexecLayerZeroBridgeProxy;
    }

    function deploy(
        address rlcCrosschain,
        address lzEndpoint,
        address initialAdmin,
        address initialUpgrader,
        address initialPauser,
        bytes32 createxSalt
    ) public returns (address) {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");

        bytes memory constructorData = abi.encode(rlcCrosschain, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(
            IexecLayerZeroBridge.initialize.selector, initialAdmin, initialUpgrader, initialPauser
        );
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createXFactory, createxSalt
        );
    }
}

contract Configure is Script {
    function run() external {
        vm.startBroadcast();

        // RLC on Arbitrum Sepolia
        address iexecLayerZeroBridgeAddress = vm.envAddress("LAYERZERO_BRIDGE_PROXY_ADDRESS");
        IexecLayerZeroBridge iexecLayerZeroBridge = IexecLayerZeroBridge(iexecLayerZeroBridgeAddress);

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("LAYERZERO_BRIDGE_ADAPTER_PROXY_ADDRESS"); // Read this variable from .env file
        uint16 ethereumSepoliaChainId = uint16(vm.envUint("LAYER_ZERO_SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Ethereum Sepolia - TODO: remove or make it chain agnostic

        // Set trusted remote
        iexecLayerZeroBridge.setPeer(ethereumSepoliaChainId, bytes32(uint256(uint160(adapterAddress))));

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = vm.envAddress("LAYERZERO_BRIDGE_PROXY_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address rlcCrosschain = vm.envAddress("RLC_CROSSCHAIN_ADDRESS");
        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            constructorData: abi.encode(rlcCrosschain, lzEndpoint),
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
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address rlcCrosschain = vm.envAddress("RLC_CROSSCHAIN_ADDRESS");
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0),
            constructorData: abi.encode(rlcCrosschain, lzEndpoint),
            contractName: "IexecLayerZeroBridgeV2Mock.sol:IexecLayerZeroBridgeV2",
            newStateVariable: 1000000 * 10 ** 9,
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
