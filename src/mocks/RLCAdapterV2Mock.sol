// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {RLCAdapter} from "../RLCAdapter.sol";

/// @notice RLCAdapterV2 - V2 implementation with additional features
/// @dev This contract inherits from RLCAdapter (V1) and adds new functionality
contract RLCAdapterV2 is RLCAdapter {
    // NEW ROLE FOR V2
    bytes32 public constant RATE_LIMITER_ROLE = keccak256("RATE_LIMITER_ROLE");

    // NEW STATE VARIABLES FOR V2
    uint256 public dailyTransferLimit;

    // NEW EVENTS FOR V2
    event DailyTransferLimitSet(uint256 newLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) RLCAdapter(_token, _lzEndpoint) {
        // Constructor logic is handled by parent
    }

    /// @notice Initializes V2 features (called after upgrade)
    /// @param _rateLimiter Address that can manage rate limits
    /// @param _dailyLimit Daily transfer limit in token units
    function initializeV2(address _rateLimiter, uint256 _dailyLimit) public reinitializer(2) {
        _grantRole(RATE_LIMITER_ROLE, _rateLimiter);
        dailyTransferLimit = _dailyLimit;

        emit DailyTransferLimitSet(_dailyLimit);
    }
    // NEW FUNCTIONS IN V2

    /// @notice Returns the contract version
    /// @return Version string
    function version() public pure returns (string memory) {
        return "2.0.0";
    }

    /// @notice Sets daily transfer limit
    /// @param _limit New daily limit
    function setDailyTransferLimit(uint256 _limit) external onlyRole(RATE_LIMITER_ROLE) {
        dailyTransferLimit = _limit;
        emit DailyTransferLimitSet(_limit);
    }

}
