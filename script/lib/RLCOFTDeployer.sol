// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";
import {RLCOFT} from "../../src/RLCOFT.sol";
import {EnvUtils} from "../UpdateEnvUtils.sol";

/// @notice Bibliothèque utilitaire pour le déploiement de contrats RLCOFT
library RLCOFTDeployer {
    /// @notice Déploie un contrat RLCOFT (ou sa variante) avec CreateX Factory
    /// @param contractCreationCode Le bytecode de création du contrat à déployer
    /// @param lzEndpoint L'adresse du endpoint LayerZero
    /// @param name Le nom du token
    /// @param symbol Le symbole du token
    /// @param owner L'adresse du propriétaire
    /// @param pauser L'adresse du pauseur
    /// @param createXFactory L'adresse de la factory CreateX
    /// @param salt Le salt pour le déploiement déterministe
    /// @return L'adresse du proxy déployé
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
