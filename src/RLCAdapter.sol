// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {Origin} from "@layerzerolabs/oapp-evm-upgradeable/contracts/oapp/OAppUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
/// There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break omnichain unified
/// liquidity by effectively creating token pools.
contract RLCAdapter is
    OFTAdapterUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    PausableUpgradeable
{
    //AccessControl Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _owner Address of the contract owner
    /// @param _pauser Address of the contract pauser
    function initialize(address _owner, address _pauser) public initializer {
        __Ownable_init(_owner);
        __OFTAdapter_init(_owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        _grantRole(UPGRADER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
        __Pausable_init();
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Override the _lzReceive function to make it pausable
     * @param _origin The origin information
     * @param _guid The unique identifier for the received LayerZero message
     * @param _message The encoded message
     * @param _executor The address of the executor
     * @param _extraData Additional data
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor,
        bytes calldata _extraData
    ) internal override whenNotPaused {
        super._lzReceive(_origin, _guid, _message, _executor, _extraData);
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
