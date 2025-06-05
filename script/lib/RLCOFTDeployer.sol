// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {EnvUtils} from "../UpdateEnvUtils.sol";

/// @notice Utility library for deploying RLCOFT-like contracts
library RLCOFTDeployer {
    /// @notice Deploys an RLCOFT contract (or its variant) using the CreateX Factory
    /// @param contractCreationCode The creation bytecode of the contract to deploy
    /// @param lzEndpoint The address of the LayerZero endpoint
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param owner The address of the owner
    /// @param pauser The address of the pauser
    /// @param createXFactory The address of the CreateX factory
    /// @param salt The salt for deterministic deployment
    /// @return The address of the deployed proxy
    function deployRLCOFT(
        bytes memory contractCreationCode,
        address lzEndpoint,
        string memory name,
        string memory symbol,
        address owner,
        address pauser,
        address createXFactory,
        bytes32 salt
    ) internal returns (address) {
        // CreateX Factory instance
        ICreateX createX = ICreateX(createXFactory);

        // Deploy the implementation contract using CreateX Factory
        address implementation =
            createX.deployCreate2(salt, abi.encodePacked(contractCreationCode, abi.encode(lzEndpoint)));
        console.log("Implementation deployed at:", implementation);

        // Deploy the proxy contract using CreateX Factory
        address proxy = createX.deployCreate2AndInit(
            salt, // salt
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(implementation, "")), // initCode
            abi.encodeWithSelector(RLCOFT.initialize.selector, name, symbol, owner, pauser), // data for initialize
            ICreateX.Values({constructorAmount: 0, initCallAmount: 0}) // values for CreateX
        );

        return proxy;
    }
}
