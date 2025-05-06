// SPDX-FileCopyrightText: 2024 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.29;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice OFTAdapterUpgradeable uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
// There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break omnichain unified 
// liquidity by effectively creating token pools.
contract RLCAdapter is OFTAdapterUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    //TODO: check the decimal: https://docs.layerzero.network/v2/developers/evm/oft/quickstart#token-supply-cap
    
    // Upgrade VoucherHub and Vouchers contracts.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // Create types required for creating vouchers, add/remove eligible assets, withdraw, [...]
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }
    
    /// @notice Initializes the contract
    /// @param _delegate Address of the contract owner
    function initialize(address _delegate) public initializer {
        __OFTAdapter_init(_delegate);
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
