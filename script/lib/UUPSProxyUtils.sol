// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdConstants} from "forge-std/StdConstants.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @notice Utility library for deploying UUPS proxy contracts and their implementations
 * using the CreateX Factory.
 */
library UUPSProxyUtils {
    /// @dev Reference to the VM cheat codes from forge-std
    Vm private constant vm = StdConstants.VM;

    /**
     * Deploys a UUPS proxy contract and its implementation in create2 mode using CreateX Factory.
     * @param contractName The name of the contract to deploy (used to fetch creation code)
     * @param constructorData The constructor arguments for the implementation contract
     * @param initializeData The initialization data for the proxy contract
     * @param createxFactory The address of the CreateX factory
     * @param createxSalt The salt for deterministic deployment
     * @return The address of the deployed proxy
     */
    function deployUsingCreateX(
        string memory contractName,
        bytes memory constructorData,
        bytes memory initializeData,
        address createxFactory,
        bytes32 createxSalt
    ) internal returns (address) {
        address implementation =
            deployImplementationUsingCreateX(contractName, constructorData, createxFactory, createxSalt);
        address proxy = ICreateX(createxFactory).deployCreate2AndInit(
            createxSalt,
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, "")), // initCode
            initializeData,
            ICreateX.Values({constructorAmount: 0, initCallAmount: 0}) // values for CreateX
        );
        console.log("UUPS Proxy deployed at:", proxy);
        return proxy;
    }

    /**
     * Deploys the implementation contract in create2 mode using CreateX factory.
     * @param contractName The name of the contract to deploy (used to fetch creation code)
     * @param constructorData The constructor arguments for the implementation contract
     * @param createxFactory The address of the CreateX factory
     * @param createxSalt The salt for deterministic deployment
     * @return The address of the deployed implementation contract
     */
    function deployImplementationUsingCreateX(
        string memory contractName,
        bytes memory constructorData,
        address createxFactory,
        bytes32 createxSalt
    ) internal returns (address) {
        bytes memory creationCode = vm.getCode(contractName);
        address implementation =
            ICreateX(createxFactory).deployCreate2(createxSalt, abi.encodePacked(creationCode, constructorData));
        console.log("Implementation deployed at:", implementation);
        return implementation;
    }

    /**
     * Upgrades a UUPS proxy contract to a new implementation.
     * @param proxyAddress address of the UUPS proxy contract to upgrade
     * @param contractName name of the contract to upgrade (e.g. "ContractV2.sol:ContractV2")
     * @param opts options for the upgrade, such as unsafeAllow and others.
     * @param initData initialization data for the proxy contract after upgrade
     * @return newImplementation address of the new implementation contract
     */
    function executeUpgrade(
        address proxyAddress,
        string memory contractName,
        bytes memory initData,
        Options memory opts
    ) internal returns (address newImplementation) {
        Upgrades.upgradeProxy(proxyAddress, contractName, initData, opts);
        newImplementation = Upgrades.getImplementationAddress(proxyAddress);
        console.log("Upgraded", contractName, " proxy to new implementation", newImplementation);
        return newImplementation;
    }
}
