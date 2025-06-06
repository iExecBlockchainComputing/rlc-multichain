// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCAdapter} from "../src/RLCAdapter.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";
import {UUPSProxyDeployer} from "./lib/UUPSProxyDeployer.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        address rlcToken = vm.envAddress("RLC_SEPOLIA_ADDRESS"); // RLC token address on sepolia testnet
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS"); // LayerZero sepolia endpoint
        address owner = vm.envAddress("OWNER_ADDRESS"); // Your actual wallet address
        bytes32 salt = vm.envBytes32("SALT");

        // Deploy the proxy contract
        address rlcAdapterProxy = deploy(lzEndpoint, owner, salt, rlcToken);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_SEPOLIA_ADAPTER_ADDRESS", rlcAdapterProxy);
        return rlcAdapterProxy;
    }

    function deploy(address lzEndpoint, address owner, bytes32 salt, address rlcToken) public returns (address) {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");
        bytes memory constructorData = abi.encode(rlcToken, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(RLCAdapter.initialize.selector, owner);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCAdapter", constructorData, initializeData, createXFactory, salt
        );
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
