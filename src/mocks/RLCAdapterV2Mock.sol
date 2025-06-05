// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice OFTAdapter V2 - Upgraded version with additional features
/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
/// There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break omnichain unified
/// liquidity by effectively creating token pools.
contract RLCAdapterV2 is OFTAdapterUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    //AccessControl Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE"); // NEW ROLE

    // NEW STATE VARIABLES FOR V2
    uint256 public maxTransferLimit; // Max transfer limit per transaction
    
    // NEW EVENT
    event TransferLimitUpdated(uint256 newLimit);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _owner Address of the contract owner
    function initialize(address _owner) public initializer {
        __Ownable_init(_owner);
        __OFTAdapter_init(_owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        _grantRole(UPGRADER_ROLE, _owner);
    }

    /// @notice Initializes V2 features (called after upgrade)
    /// @param _operator Address to grant operator role
    /// @param _maxTransferLimit Initial max transfer limit
    function initializeV2(address _operator, uint256 _maxTransferLimit) public reinitializer(2) {
        _grantRole(OPERATOR_ROLE, _operator);
        maxTransferLimit = _maxTransferLimit;
        
        emit TransferLimitUpdated(_maxTransferLimit);
    }

    // NEW FUNCTIONS IN V2

    /// @notice Returns the contract version
    /// @return Version string
    function version() public pure returns (string memory) {
        return "2.0.0";
    }

    /// @notice Sets the maximum transfer limit per transaction
    /// @param _limit New maximum transfer limit
    function setMaxTransferLimit(uint256 _limit) external onlyRole(OPERATOR_ROLE) {
        maxTransferLimit = _limit;
        emit TransferLimitUpdated(_limit);
    }

    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
