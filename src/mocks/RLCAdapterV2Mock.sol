// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice RLCAdapterV2 - V2 implementation with additional features
/// @dev This is a mock contract for testing upgrade functionality
contract RLCAdapterV2 is
    OFTAdapterUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    PausableUpgradeable
{
    // AccessControl Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant RATE_LIMITER_ROLE = keccak256("RATE_LIMITER_ROLE"); // NEW ROLE

    // NEW STATE VARIABLES FOR V2
    uint256 public dailyTransferLimit;

    // NEW EVENT
    event DailyTransferLimitSet(uint256 newLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract (V1 initialization)
    /// @param _owner Address of the contract owner
    /// @param _pauser Address that can pause/unpause
    function initialize(address _owner, address _pauser) public initializer {
        __Ownable_init(_owner);
        __OFTAdapter_init(_owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        __Pausable_init();
        _grantRole(UPGRADER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
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

    // V1 Functions (unchanged)
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        whenNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }

    function _credit(address _to, uint256 _amountLD, uint32 _srcEid)
        internal
        virtual
        override
        whenNotPaused
        returns (uint256 amountReceivedLD)
    {
        return super._credit(_to, _amountLD, _srcEid);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
