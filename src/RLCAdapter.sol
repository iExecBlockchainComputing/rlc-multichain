// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
// There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break omnichain unified
// liquidity by effectively creating token pools.
contract RLCAdapter is OFTAdapterUpgradeable, UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable {
    // Upgrader Role RLCAdapter contracts.
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    // Bridge Minter Role required for minting RLC Token
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");

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
