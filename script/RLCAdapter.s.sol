// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address owner = vm.envAddress("OWNER_ADDRESS"); // Your actual wallet address

        Options memory opts;
        opts.constructorData = abi.encode(rlcToken, lzEndpoint);

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            RLCAdapter.initialize.selector,
            owner
        );
        // Deploy the UUPS proxy using OpenZeppelin Upgrades
        address rlcAdapterProxyAddress = Upgrades.deployUUPSProxy(
            "RLCAdapter.sol:RLCAdapter",
            initData,
            opts
        );
        console.log("RLCAdapter proxy deployed at:", rlcAdapterProxyAddress);
        address implementationAddress = Upgrades.getImplementationAddress(rlcAdapterProxyAddress);
        console.log("RLCAdapter implementation deployed at:", implementationAddress);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_ADDRESS", rlcAdapterProxyAddress);
        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_IMPLEMENTATION_ADDRESS", implementationAddress);
        return rlcAdapterProxyAddress;
    }
}

contract Configure is Script {
    function run() external {
        vm.startBroadcast();

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("RLC_SEPOLIA_ADAPTER_ADDRESS"); // Read this variable from .env file
        RLCAdapter adapter = RLCAdapter(adapterAddress);

        // RLCOFT on Arbitrum Sepolia
        address oftAddress = vm.envAddress("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS");
        uint16 arbitrumSepoliaChainId = uint16(vm.envUint("LAYER_ZERO_ARBITRUM_SEPOLIA_CHAIN_ID")); //TODO: remove or make it chain agnostic
        // Set trusted remote
        adapter.setPeer(arbitrumSepoliaChainId, bytes32(uint256(uint160(oftAddress))));

        vm.stopBroadcast();
    }
}
