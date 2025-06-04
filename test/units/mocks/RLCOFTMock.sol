// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../../src/RLCOFT.sol";
import {ICreateX} from "@createx/contracts/ICreateX.sol";

/// @notice Mock contract that extends RLCOFT with mint/burn functions for testing
contract RLCOFTMock is RLCOFT {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) RLCOFT(_lzEndpoint) {}

    /// @notice Mints tokens to a specified address
    /// @param _to Address to mint tokens to
    /// @param _amount Amount of tokens to mint
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}

contract Deploy is Test {
    function deploy(
        address lzEndpoint,
        string memory name,
        string memory symbol,
        address owner,
        address pauser,
        address createXFactory,
        bytes32 salt 
    ) public returns (address) {
        // CreateX Factory address
        ICreateX createX = ICreateX(createXFactory);

        // Deploy the implementation contract using CreateX Factory
        address rlcOFTMockImplementation =
            createX.deployCreate2(salt, abi.encodePacked(type(RLCOFTMock).creationCode, abi.encode(lzEndpoint)));
        console.log("RLCOFTMock implementation deployed at:", rlcOFTMockImplementation);

        // Deploy the proxy contract using CreateX Factory
        // The proxy contract will be initialized with the implementation address and the constructor arguments
        address rlcOFTProxy = createX.deployCreate2AndInit(
            salt, // salt
            abi.encodePacked(type(ERC1967Proxy).creationCode, abi.encode(rlcOFTMockImplementation, "")), // initCode
            abi.encodeWithSelector(RLCOFT.initialize.selector, name, symbol, owner, pauser), // data for initialize
            ICreateX.Values({constructorAmount: 0, initCallAmount: 0}) // values for CreateX
        );
        return rlcOFTProxy;
    }
}
