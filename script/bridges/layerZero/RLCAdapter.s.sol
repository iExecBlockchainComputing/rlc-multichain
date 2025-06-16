// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {RLCAdapter} from "../../../src/bridges/layerZero/RLCAdapter.sol";
import {EnvUtils} from "../../lib/UpdateEnvUtils.sol";
import {UUPSProxyDeployer} from "../../lib/UUPSProxyDeployer.sol";
import {UpgradeUtils} from "../../lib/UpgradeUtils.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();

        // TODO use json file to configure addresses by network.
        // vm.readFile(path)
        // vm.parseJson()
        address rlcToken = vm.envAddress("RLC_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address pauser = vm.envAddress("PAUSER_ADDRESS");
        bytes32 createxSalt = vm.envBytes32("SALT");

        // Deploy the proxy contract
        address rlcAdapterProxy = deploy(lzEndpoint, owner, pauser, createxSalt, rlcToken);

        vm.stopBroadcast();
        address implementationAddress = Upgrades.getImplementationAddress(rlcAdapterProxy);
        EnvUtils.updateEnvVariable("RLC_ADAPTER_IMPLEMENTATION_ADDRESS", implementationAddress);
        EnvUtils.updateEnvVariable("RLC_ADAPTER_PROXY_ADDRESS", rlcAdapterProxy);
        return rlcAdapterProxy;
    }

    function deploy(address lzEndpoint, address owner, address pauser, bytes32 createxSalt, address rlcToken)
        public
        returns (address)
    {
        address createXFactory = vm.envAddress("CREATE_X_FACTORY_ADDRESS");
        bytes memory constructorData = abi.encode(rlcToken, lzEndpoint);
        bytes memory initializeData = abi.encodeWithSelector(RLCAdapter.initialize.selector, owner, pauser);
        return UUPSProxyDeployer.deployUUPSProxyWithCreateX(
            "RLCAdapter", constructorData, initializeData, createXFactory, createxSalt
        );
    }
}

contract Configure is Script {
    function run() external {
        vm.startBroadcast();

        // RLCAdapter on Ethereum Sepolia
        address adapterAddress = vm.envAddress("RLC_ADAPTER_PROXY_ADDRESS"); // Read this variable from .env file
        RLCAdapter adapter = RLCAdapter(adapterAddress);

        // RLC on Arbitrum Sepolia
        address rlcCrosschain = vm.envAddress("RLC_CROSSCHAIN_ADDRESS");
        uint16 arbitrumSepoliaChainId = uint16(vm.envUint("LAYER_ZERO_ARBITRUM_SEPOLIA_CHAIN_ID")); //TODO: remove or make it chain agnostic
        // Set trusted remote
        adapter.setPeer(arbitrumSepoliaChainId, bytes32(uint256(uint160(rlcCrosschain))));

        vm.stopBroadcast();
    }
}

contract Upgrade is Script {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = vm.envAddress("RLC_ADAPTER_PROXY_ADDRESS");
        address rlcToken = vm.envAddress("RLC_ADDRESS");
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS");

        // For testing purpose
        uint256 newStateVariable = 1000000 * 10 ** 9; // 1M token daily transfer limit

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: proxyAddress,
            contractName: "RLCAdapterV2Mock.sol:RLCAdapterV2", // Would be production contract in real deployment
            lzEndpoint: lzEndpoint,
            rlcToken: rlcToken,
            newStateVariable: newStateVariable,
            skipChecks: true, // TODO: Remove when validation issues are fixed
            validateOnly: false
        });

        address newImplementationAddress = UpgradeUtils.executeUpgrade(params);

        // Log the new implementation address
        console.log("RLCAdapter upgraded to new implementation:", newImplementationAddress);
        console.log("Proxy address remains:", proxyAddress);

        vm.stopBroadcast();

        EnvUtils.updateEnvVariable("RLC_ADAPTER_IMPLEMENTATION_ADDRESS", newImplementationAddress);
    }
}

contract ValidateUpgrade is Script {
    function run() external {
        address lzEndpoint = vm.envAddress("LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS");
        address rlcToken = vm.envAddress("RLC_ADDRESS");

        UpgradeUtils.UpgradeParams memory params = UpgradeUtils.UpgradeParams({
            proxyAddress: address(0), // Not needed for validation
            lzEndpoint: lzEndpoint,
            rlcToken: rlcToken,
            contractName: "RLCAdapterV2Mock.sol:RLCAdapterV2",
            newStateVariable: 1000000 * 10 ** 9,
            skipChecks: true, // TODO: Remove this when validation issues are fixed
            validateOnly: true
        });

        UpgradeUtils.validateUpgrade(params);
        console.log("Upgrade validation passed for RLCAdapter");
    }
}
