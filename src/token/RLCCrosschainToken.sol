// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";

/**
 * This contract is an upgradeable (UUPS) ERC20 token with cross-chain capabilities.
 * It implements the ERC-7802 (https://eips.ethereum.org/EIPS/eip-7802) standard for
 * cross-chain token transfers. It allows minting and burning of tokens as requested
 * by permitted bridge contracts.
 *
 * The code is inspired by OpenZeppelin's community contract `ERC20Bridgeable`
 * https://github.com/OpenZeppelin/openzeppelin-community-contracts/blob/075587479556632d3dd9e9e3b37417cabf3e26a3/contracts/token/ERC20/extensions/ERC20Bridgeable.sol
 */
contract RLCCrosschainToken is
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol, address admin, address upgrader) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    // TODO crosschainMint and crosschainBurn

    /**
     * @dev Authorizes upgrades of the proxy. It can only be called by
     * an account with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
