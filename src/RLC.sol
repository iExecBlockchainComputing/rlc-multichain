// SPDX-FileCopyrightText: 2024 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.29;

import { OFTUpgradeable } from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract RLC is OFTUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    //TODO: check the decimal: https://docs.layerzero.network/v2/developers/evm/oft/quickstart#token-supply-cap
    
    // Upgrade VoucherHub and Vouchers contracts.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // Create types required for creating vouchers, add/remove eligible assets, withdraw, [...]
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _lzEndpoint) OFTUpgradeable(_lzEndpoint) {
        _disableInitializers();
    }
    
    /// @notice Initializes the contract
    /// @param _name Name of the token
    /// @param _symbol Symbol of the token
    /// @param _delegate Address of the contract owner
    function initialize(string memory _name, string memory _symbol, address _delegate) public initializer {
        __OFT_init(_name, _symbol, _delegate);
        __Ownable_init(_delegate);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _delegate);
        _grantRole(UPGRADER_ROLE, _delegate);
    }

    /// @notice Authorizes an upgrade to a new implementation
    /// @dev Can only be called by the owner
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    function owner() public view override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable) returns (address) {
        return AccessControlDefaultAdminRulesUpgradeable.owner();
    }
}
