// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {IexecLayerZeroBridge} from "../src/IexecLayerZeroBridge.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcChainX = vm.envAddress("RLC_CHAIN_X");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        bytes32 salt = vm.envBytes32("SALT");

        address IexecLayerZeroBridgeProxy = deploy(rlcChainX, lzEndpoint, owner, pauser, salt);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", IexecLayerZeroBridgeProxy);
        return IexecLayerZeroBridgeProxy;
    }

    function deploy(address rlcChainX, address lzEndpoint, address owner, address pauser, bytes32 salt)
        public
        returns (address)
    {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");

        bytes memory constructorData = abi.encode(rlcChainX, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(IexecLayerZeroBridge.initialize.selector, owner, pauser);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "IexecLayerZeroBridge", constructorData, initializeData, createXFactory, salt
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
