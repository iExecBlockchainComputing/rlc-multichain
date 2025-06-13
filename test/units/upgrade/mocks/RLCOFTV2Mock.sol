// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCOFT} from "../../../../src/RLCOFT.sol";


/**
 * @title RLCOFTV2 - V2 implementation with additional features
 * @author IEXEC BLOCKCHAIN TECH
 * @notice This contract inherits from RLCOFT (V1) and adds new functionality
 */
contract RLCOFTV2 is RLCOFT {
    // NEW STATE VARIABLES FOR V2
    uint256 public newStateVariable;

    constructor(address _lzEndpoint) RLCOFT(_lzEndpoint) {}

    /**
     * @notice Initializes V2 features (called after upgrade)
     * @param _newStateVariable New state variable description
     */
    function initializeV2(uint256 _newStateVariable) public reinitializer(2) {
        newStateVariable = _newStateVariable;
    }
}
