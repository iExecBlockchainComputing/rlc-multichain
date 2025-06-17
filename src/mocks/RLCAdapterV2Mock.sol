// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {RLCAdapter} from "../bridges/layerZero/RLCAdapter.sol";

/**
 * @notice RLCAdapterV2 - V2 implementation with additional features
 * @dev This contract inherits from RLCAdapter (V1) and adds new functionality
 * @custom:oz-upgrades-from src/RLCAdapter.sol:RLCAdapter
 */
contract RLCAdapterV2 is RLCAdapter {
    // NEW STATE VARIABLES FOR V2
    uint256 public newStateVariable;

    //  @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) RLCAdapter(_token, _lzEndpoint) {}

    /**
     * @notice Initializes V2 features (called after upgrade)
     * @param _newStateVariable New state variable description
     *
     * @custom:oz-upgrades-validate-as-initializer
     */
    function initializeV2(uint256 _newStateVariable) public reinitializer(2) {
        newStateVariable = _newStateVariable;
    }
}
