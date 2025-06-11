// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCOFT} from "../RLCOFT.sol";

/**
 * @title RLCOFTV2 - V2 implementation with additional features
 * @author IEXEC BLOCKCHAIN TECH
 * @notice This contract inherits from RLCOFT (V1) and adds new functionality
 */

contract RLCOFTV2 is RLCOFT {

    // NEW STATE VARIABLES FOR V2
    uint256 public dailyMintLimit;
    constructor(address _lzEndpoint) RLCOFT(_lzEndpoint) {}

    /**
     * @notice Initializes V2 features (called after upgrade)
     * @param _dailyMintLimit Daily mint limit
     */
    function initializeV2(uint256 _dailyMintLimit) public reinitializer(2) {
        dailyMintLimit = _dailyMintLimit;
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
