// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script} from "forge-std/Script.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {IExecOFTBridge} from "../src/IExecOFTBridge.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address tokenChainX = vm.envAddress("TOKEN_CHAIN_X");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        bytes32 salt = vm.envBytes32("SALT");

        address rlcOFTProxy = deploy(tokenChainX, lzEndpoint, owner, pauser, salt);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", rlcOFTProxy);
        return rlcOFTProxy;
    }

    function deploy(address tokenChainX, address lzEndpoint, address owner, address pauser, bytes32 salt)
        public
        returns (address)
    {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");

        bytes memory constructorData = abi.encode(tokenChainX, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(IExecOFTBridge.initialize.selector, owner, pauser);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "IExecOFTBridge", constructorData, initializeData, createXFactory, salt
        );
    }
}

contract Configure is Script {
    function run() external {
        vm.startBroadcast();

        // IExecOFTBridge on Arbitrum Sepolia
        address oftAddress = vm.envAddress("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS");
        IExecOFTBridge oft = IExecOFTBridge(oftAddress);

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("RLC_SEPOLIA_ADAPTER_ADDRESS"); // Read this variable from .env file
        uint16 ethereumSepoliaChainId = uint16(vm.envUint("LAYER_ZERO_SEPOLIA_CHAIN_ID")); // LayerZero chain ID for Ethereum Sepolia - TODO: remove or make it chain agnostic

        // Set trusted remote
        oft.setPeer(ethereumSepoliaChainId, bytes32(uint256(uint160(adapterAddress))));

        vm.stopBroadcast();
    }
}
