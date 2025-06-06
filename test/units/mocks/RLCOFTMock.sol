// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import {RLCOFT} from "../../../src/RLCOFT.sol";

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
