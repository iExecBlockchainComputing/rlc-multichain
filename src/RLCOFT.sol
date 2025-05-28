// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {OFTUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {ITokenSpender} from "src/ITokenSpender.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract RLCOFT is OFTUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, PausableUpgradeable {
    //AccessControl Roles
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _owner Address of the contract owner
    /// @param _pauser Address of the contract pauser
    function initialize(string memory _name, string memory _symbol, address _owner, address _pauser)
        public
        initializer
    {
        __Ownable_init(_owner);
        __OFT_init(_name, _symbol, _owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        __Pausable_init();
        _grantRole(UPGRADER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * Approve and then call the approved contract in a single tx
     */
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) external returns (bool) {
        ITokenSpender spender = ITokenSpender(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
        return false;
    }

    /**
     * @dev Override the decimals function to return 9 instead of the default 18
     * @return The number of decimals used in the token
     */
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    /**
     * @dev See {ERC20-_update}.
     * Override this functions to prevent its execution when the contract is paused.
     */
    function _update(address from, address to, uint256 value) internal virtual override whenNotPaused {
        super._update(from, to, value);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by the upgrader.
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
