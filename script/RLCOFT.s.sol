// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        string memory name = vm.envString("RLC_OFT_TOKEN_NAME");
        string memory symbol = vm.envString("RLC_TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        return runWithParams(name, symbol, lzEndpoint, owner, pauser);
    }

    function runWithParams(
        string memory name,
        string memory symbol,
        address lzEndpoint,
        address owner,
        address pauser
    ) public returns (address){
        vm.startBroadcast();
        // Deploy the implementation contract.
        RLCOFT rlcOFTImplementation = new RLCOFT(lzEndpoint);
        console.log("RLCOFT implementation deployed at:", address(rlcOFTImplementation));
        // Deploy the proxy contract.
        address rlcOFTProxyAddress = address(
            new ERC1967Proxy(
                address(rlcOFTImplementation),
                abi.encodeWithSelector(rlcOFTImplementation.initialize.selector, name, symbol, owner, pauser)
            )
        );
        console.log("RLCOFT proxy deployed at:", rlcOFTProxyAddress);
        vm.stopBroadcast();
        // Save the proxy address to .env file.
        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", rlcOFTProxyAddress);
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
