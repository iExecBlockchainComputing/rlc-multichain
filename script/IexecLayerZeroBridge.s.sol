// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {IexecLayerZeroBridge} from "../src/IexecLayerZeroBridge.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {UpgradeUtils} from "./lib/UpgradeUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcChainX = vm.envAddress("RLC_ARBITRUM_SEPOLIA_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        bytes32 createxSalt = vm.envBytes32("SALT");

        address IexecLayerZeroBridgeProxy = deploy(rlcChainX, lzEndpoint, owner, pauser, createxSalt);

        vm.stopBroadcast();

        address implementationAddress = Upgrades.getImplementationAddress(IexecLayerZeroBridgeProxy);
        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS", implementationAddress);
        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", IexecLayerZeroBridgeProxy);
        return IexecLayerZeroBridgeProxy;
    }

    function deploy(address rlcChainX, address lzEndpoint, address owner, address pauser, bytes32 createxSalt)
        public
        returns (address)
    {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");

        bytes memory constructorData = abi.encode(rlcChainX, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(IexecLayerZeroBridge.initialize.selector, owner, pauser);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createXFactory, createxSalt
        );
    }
}

contract Configure is Script {
    function run() external {
        vm.startBroadcast();

        // RLCOFT on Arbitrum Sepolia
        address oftAddress = vm.envAddress("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS");
        RLCOFT oft = RLCOFT(oftAddress);

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("RLC_SEPOLIA_ADAPTER_ADDRESS"); // Read this variable from .env file
        uint16 ethereumSepoliaChainId = uint16(vm.envUint("LAYER_ZERO_SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Ethereum Sepolia - TODO: remove or make it chain agnostic

        // Set trusted remote
        oft.setPeer(ethereumSepoliaChainId, bytes32(uint256(uint160(adapterAddress))));

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = vm.envAddress("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9;

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            rlcToken: address(0), // Not used for OFT
            contractName: "RLCOFTV2Mock.sol:RLCOFTV2", // Would be production contract in real deployment
            lzEndpoint: lzEndpoint,
            contractType: UpgradeUtils.ContractType.OFT,
            newStateVariable: newStateVariable,
            skipChecks: true, // TODO: Remove when validation issues are fixed opts.unsafeAllow
            validateOnly: false
        });

        address newImplementationAddress = UpgradeUtils.executeUpgradeOFT(params);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0),
            lzEndpoint: lzEndpoint,
            rlcToken: address(0), // Not used for OFT
            contractName: "RLCOFTV2Mock.sol:RLCOFTV2",
            contractType: UpgradeUtils.ContractType.OFT,
            newStateVariable: 1000000 * 10 ** 9,
            skipChecks: true, // TODO: Remove this when validation issues are fixed opts.unsafeAllow
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
    }
}
