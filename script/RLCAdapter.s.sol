// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {RLCAdapterV2} from "../src/mocks/RLCAdapterV2Mock.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address owner = vm.envAddress("OWNER_ADDRESS"); // Your actual wallet address

        Options memory opts;
        opts.constructorData = abi.encode(rlcToken, lzEndpoint);
        // Skip validation for testing purposes
        opts.unsafeSkipAllChecks = true;

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

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = vm.envAddress("RLC_SEPOLIA_ADAPTER_ADDRESS");
        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS");

        // For testing purpose
        address operator = vm.envAddress("OWNER_ADDRESS"); 
        uint256 maxTransferLimit = 1000000 * 10**9; // 1M token max transfer limit

        // Set up upgrade options
        Options memory opts;
        opts.constructorData = abi.encode(rlcToken, lzEndpoint);

        bytes memory initData = abi.encodeWithSelector(
            RLCAdapterV2.initializeV2.selector,
            operator,
            maxTransferLimit
        );

        // Upgrade the proxy to a new implementation
        Upgrades.upgradeProxy(
            proxyAddress,
            "RLCAdapterV2.sol:RLCAdapterV2",
            initData,
            opts
        );

        // Log the new implementation address
        address newImplementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        console.log("RLCAdapter upgraded to new implementation:", newImplementationAddress);
        console.log("Proxy address remains:", proxyAddress);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {
        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS");
        
        Options memory opts;
        opts.constructorData = abi.encode(rlcToken, lzEndpoint);

        // Validate that the upgrade is safe
        Upgrades.validateUpgrade("RLCAdapterV2.sol:RLCAdapterV2", opts);
        console.log("Upgrade validation passed for RLCAdapter");
    }
}
