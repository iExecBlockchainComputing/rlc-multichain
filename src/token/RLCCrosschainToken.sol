// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC7802} from "../interfaces/IERC7802.sol";

/**
 * This contract is an upgradeable (UUPS) ERC20 token with cross-chain capabilities.
 * It implements the ERC-7802 (https://eips.ethereum.org/EIPS/eip-7802) standard for
 * cross-chain token transfers. It allows minting and burning of tokens as requested
 * by permitted bridge contracts.
 * To whitelist a token bridge contract, the admin (with `DEFAULT_ADMIN_ROLE`) sends
 * a transaction to grant the role `TOKEN_BRIDGE_ROLE` to the bridge contract address
 * using `grantRole` function.
 *
 * The code is inspired by OpenZeppelin's community contract `ERC20Bridgeable`
 * https://github.com/OpenZeppelin/openzeppelin-community-contracts/blob/075587479556632d3dd9e9e3b37417cabf3e26a3/contracts/token/ERC20/extensions/ERC20Bridgeable.sol
 */
contract RLCCrosschainToken is
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    IERC7802
{
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor() {
        _disableInitializers();
    }

    /**
     * Initializes the contract with the given parameters.
     * @param name name of the token
     * @param symbol symbol of the token
     * @param admin address of the admin wallet
     * @param upgrader address of the upgrader wallet
     */
    function initialize(string memory name, string memory symbol, address admin, address upgrader) public initializer {
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, admin);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC7802).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC7802-crosschainMint}.
     * Does not mint if `to` is the zero address.
     * Reverts if the caller does not have the `TOKEN_BRIDGE_ROLE`.
     * Emits a {CrosschainMint} event.
     */
    function crosschainMint(address to, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        _mint(to, value);
        emit CrosschainMint(to, value, _msgSender());
    }

    /**
     * @dev See {IERC7802-crosschainBurn}.
     * Does not burn if `from` is the zero address.
     * Reverts if the caller does not have the `TOKEN_BRIDGE_ROLE`.
     * Emits a {CrosschainBurn} event.
     */
    function crosschainBurn(address from, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        _burn(from, value);
        emit CrosschainBurn(from, value, _msgSender());
    }

    /**
     * Uses the same decimals number as the original RLC token.
     */
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    /**
     * @dev Authorizes upgrades of the proxy. It can only be called by
     * an account with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
