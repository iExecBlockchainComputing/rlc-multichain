// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCOFT} from "../RLCOFT.sol";

/// @notice RLCOFTV2 - V2 implementation with additional features
/// @dev This contract inherits from RLCOFT (V1) and adds new functionality
/// @custom:oz-upgrades-from src/RLCOFT.sol:RLCOFT
contract RLCOFTV2 is RLCOFT {
    // NEW ROLE FOR V2
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // NEW STATE VARIABLES FOR V2
    uint256 public dailyMintLimit;

    // NEW EVENTS FOR V2
    event DailyMintLimitUpdated(uint256 newLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) RLCOFT(_lzEndpoint) {}

    /// @notice Initializes V2 features (called after upgrade)
    /// @param _minter Address to grant minter role
    /// @param _dailyMintLimit Daily mint limit
    function initializeV2(address _minter, uint256 _dailyMintLimit) public reinitializer(2) {
        _grantRole(MINTER_ROLE, _minter);
        dailyMintLimit = _dailyMintLimit;

        emit DailyMintLimitUpdated(_dailyMintLimit);
    }

    // NEW FUNCTIONS IN V2

    /// @notice Returns the contract version
    /// @return Version string
    function version() public pure returns (string memory) {
        return "2.0.0";
    }

    /// @notice Sets the daily mint limit
    /// @param _limit New daily mint limit
    function setDailyMintLimit(uint256 _limit) external onlyRole(MINTER_ROLE) {
        dailyMintLimit = _limit;
        emit DailyMintLimitUpdated(_limit);
    }
}
