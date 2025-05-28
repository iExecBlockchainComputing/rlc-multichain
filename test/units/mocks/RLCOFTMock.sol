// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "../../../src/RLCOFT.sol";

/// @notice Mock contract that extends RLCOFT with mint/burn functions for testing
contract RLCOFTMock is RLCOFT {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) RLCOFT(_lzEndpoint) {}

    /// @notice Mints tokens to a specified address
    /// @dev Can only be called by addresses with BRIDGE_ROLE
    /// @param _to Address to mint tokens to
    /// @param _amount Amount of tokens to mint
    function mint(address _to, uint256 _amount) public onlyRole(BRIDGE_ROLE) {
        _mint(_to, _amount);
    }

    /// @notice Burns tokens from a specified address
    /// @dev Can only be called by addresses with BRIDGE_ROLE
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _amount) public onlyRole(BRIDGE_ROLE) {
        _burn(msg.sender, _amount);
    }
}

contract Deploy is Test {
    function run(address lzEndpoint, address owner, address pauser) external returns (address) {
        string memory name = "RLC_OFT_TOKEN_NAME";
        string memory symbol = "RLC_TOKEN_SYMBOL";

        RLCOFTMock rlcOFTMockImplementation = new RLCOFTMock(lzEndpoint);
        console.log("RLCOFTMock implementation deployed at:", address(rlcOFTMockImplementation));

        // Deploy the proxy contract
        address rlcOFTProxyAddress = address(
            new ERC1967Proxy(
                address(rlcOFTMockImplementation),
                abi.encodeWithSelector(rlcOFTMockImplementation.initialize.selector, name, symbol, owner, pauser)
            )
        );
        console.log("RLCOFTMock proxy deployed at:", rlcOFTProxyAddress);
        return rlcOFTProxyAddress;
    }
}
