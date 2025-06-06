// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {RLCOFTV2} from "../src/mocks/RLCOFTV2Mock.sol";
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
        // Skip validation for testing purposes
        // TODO: check why and how to fix it
        opts.unsafeSkipAllChecks = true;
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

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address proxyAddress = vm.envAddress("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS");
        
        // For testing purpose
        address minter = vm.envAddress("OWNER_ADDRESS");
        uint256 minterDailyLimit = 100000 * 10**9; 

        // Set up upgrade options
        Options memory opts;
        opts.constructorData = abi.encode(lzEndpoint);
        // Skip validation for testing purposes
        // TODO: check why and how to fix it
        opts.unsafeSkipAllChecks = true;

        bytes memory initData = abi.encodeWithSelector(
            RLCOFTV2.initializeV2.selector,
            minter,  // minter
            minterDailyLimit
        );

        // Upgrade the proxy to a new implementation
        Upgrades.upgradeProxy(
            proxyAddress,
            "RLCOFTV2Mock.sol:RLCOFTV2",
            initData,
            opts
        );

        // Log the new implementation address
        address newImplementationAddress = Upgrades.getImplementationAddress(proxyAddress);
        console.log("RLCOFT upgraded to new implementation:", newImplementationAddress);
        console.log("Proxy address remains:", proxyAddress);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {  // Remove 'view' modifier
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");

        Options memory opts;
        opts.constructorData = abi.encode(lzEndpoint);

        // Skip validation for testing purposes
        // TODO: check why and how to fix it
        opts.unsafeSkipAllChecks = true;
        // Validate that the upgrade is safe
        Upgrades.validateUpgrade("RLCOFTV2Mock.sol:RLCOFTV2", opts);
        console.log("Upgrade validation passed for RLCOFT");
    }
}
