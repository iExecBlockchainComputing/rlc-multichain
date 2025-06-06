// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";
import {StdConstants} from "forge-std/StdConstants.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";

/// @notice Utility library for deploying UUPS proxy contracts and their implementations using the CreateX Factory
library UUPSProxyDeployer {
    /// @dev Reference to the VM cheat codes from forge-std
    Vm private constant vm = StdConstants.VM;

    /// @notice Deploys a UUPS proxy contract and its implementation using the CreateX Factory
    /// @param contractName The name of the contract to deploy (used to fetch creation code)
    /// @param constructorData The constructor arguments for the implementation contract
    /// @param initializeData The initialization data for the proxy contract
    /// @param createXFactory The address of the CreateX factory
    /// @param salt The salt for deterministic deployment
    /// @return The address of the deployed proxy
    function deployUUPSProxyWithCreateX(
        string memory contractName,
        bytes memory constructorData,
        bytes memory initializeData,
        address createXFactory,
        bytes32 salt
    ) internal returns (address) {
        // CreateX Factory instance
        ICreateX createX = ICreateX(createXFactory);
        address implementation = deployImplementationWithCreateX(contractName, constructorData, createX, salt);

        // Deploy the proxy contract using CreateX Factory
        address proxy = createX.deployCreate2AndInit(
            salt, // salt
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, "")), // initCode
            initializeData, // data for initialize
            ICreateX.Values({constructorAmount: 0, initCallAmount: 0}) // values for CreateX
        );
        console.log("UUPS Proxy deployed at:", proxy);

        return proxy;
    }

    /// @notice Deploys the implementation contract using the CreateX Factory
    /// @param contractName The name of the contract to deploy (used to fetch creation code)
    /// @param constructorData The constructor arguments for the implementation contract
    /// @param createXFactory The address of the CreateX factory
    /// @param salt The salt for deterministic deployment
    /// @return The address of the deployed implementation contract
    function deployImplementationWithCreateX(
        string memory contractName,
        bytes memory constructorData,
        ICreateX createXFactory,
        bytes32 salt
    ) internal returns (address) {
        // Deploy the implementation contract using CreateX Factory
        bytes memory creationCode = vm.getCode(contractName);
        address implementation = createXFactory.deployCreate2(salt, abi.encodePacked(creationCode, constructorData));
        console.log("Implementation deployed at:", implementation);

        return implementation;
    }
}
