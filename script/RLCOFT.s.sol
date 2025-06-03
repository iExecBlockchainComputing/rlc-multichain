// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        string memory name = vm.envString("RLC_OFT_TOKEN_NAME");
        string memory symbol = vm.envString("RLC_TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");

        // Set up deployment options
        Options memory opts;
        opts.constructorData = abi.encode(lzEndpoint);
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            RLCOFT.initialize.selector,
            name,
            symbol,
            owner,
            pauser
        );
        // Deploy the UUPS proxy using OpenZeppelin Upgrades
        address rlcOFTProxyAddress = Upgrades.deployUUPSProxy(
            "RLCOFT.sol:RLCOFT",
            initData,
            opts
        );
        console.log("RLCOFT proxy deployed at:", rlcOFTProxyAddress);
        address implementationAddress = Upgrades.getImplementationAddress(rlcOFTProxyAddress);
        console.log("RLCOFT implementation deployed at:", implementationAddress);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", rlcOFTProxyAddress);
        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS", implementationAddress);
        return rlcOFTProxyAddress;
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
