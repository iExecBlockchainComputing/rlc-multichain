// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {RLCAdapter} from "../RLCAdapter.sol";
/**
 * @notice RLCAdapterV2 - V2 implementation with additional features
 * @dev This contract inherits from RLCAdapter (V1) and adds new functionality
 * @custom:oz-upgrades-from src/RLCAdapter.sol:RLCAdapter
 */
contract RLCAdapterV2 is RLCAdapter {
    // NEW STATE VARIABLES FOR V2
    uint256 public dailyTransferLimit;

    //  @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) RLCAdapter(_token, _lzEndpoint) {
    }

    /**
     * @notice Initializes V2 features (called after upgrade)
     * @param _dailyLimit Daily transfer limit in token units
     */
    function initializeV2(uint256 _dailyLimit) public reinitializer(2) {
        dailyTransferLimit = _dailyLimit;
    }

    // NEW FUNCTIONS IN V2
    /**
     * @notice Returns the contract version
     * @return Version string
    */
    function version() public pure returns (string memory) {
        return "2.0.0";
    }
}
