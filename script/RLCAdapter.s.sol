// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin-foundry/contracts/Upgrades.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address ownerAddress = vm.envAddress("OWNER_ADDRESS"); // Your actual wallet address

        // Deploy the RLCAdapter contract
        RLCAdapter rlcAdapterImplementation = new RLCAdapter(rlcToken, lzEndpoint);
        console.log("RLCAdapter implementation deployed at:", address(rlcAdapterImplementation));

        // Deploy the proxy contract
        ICreateX createX = ICreateX(vm.envAddress("CREATE_X_FACTORY_ADDRESS"));
        address rlcAdapterProxy = createX.deployCreate2AndInit(
            vm.envBytes32("SALT"), // salt
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(address(rlcAdapterImplementation), "")), // initCode
            abi.encodeWithSelector(rlcAdapterImplementation.initialize.selector, ownerAddress), // data for initialize
            ICreateX.Values({constructorAmount: 0, initCallAmount: 0}) // values for CreateX
        );
        console.log("RLCAdapter proxy deployed at:", rlcAdapterProxy);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_ADDRESS", rlcAdapterProxy);
        return rlcAdapterProxy;
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
