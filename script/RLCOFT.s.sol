// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCOFT} from "../src/RLCOFT.sol";
import {RLCOFTDeployer} from "./lib/RLCOFTDeployer.sol";
import {EnvUtils} from "./UpdateEnvUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        string memory name = vm.envString("RLC_OFT_TOKEN_NAME");
        string memory symbol = vm.envString("RLC_TOKEN_SYMBOL");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");
        bytes32 salt = vm.envBytes32("SALT");

        address rlcOFTProxy = deploy(lzEndpoint, name, symbol, owner, pauser, createXFactory, salt);
        console.log("RLCOFT proxy deployed at:", rlcOFTProxy);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ARBITRUM_SEPOLIA_OFT_ADDRESS", rlcOFTProxy);
        return rlcOFTProxy;
    }

    function deploy(
        address lzEndpoint,
        string memory name,
        string memory symbol,
        address owner,
        address pauser,
        address createXFactory,
        bytes32 salt
    ) public returns (address) {
        return RLCOFTDeployer.deployRLCOFT(
            type(RLCOFT).creationCode, lzEndpoint, name, symbol, owner, pauser, createXFactory, salt
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
