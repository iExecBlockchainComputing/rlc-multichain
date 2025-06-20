// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC7802} from "./interfaces/IERC7802.sol";

contract LiquidityUnifier is UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, IERC7802 {
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    IERC20Metadata public immutable RLC_TOKEN;

    /**
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address rlcToken) {
        _disableInitializers();
        RLC_TOKEN = IERC20Metadata(rlcToken);
    }

    /**
     * Initializes the contract with the given parameters.
     * @param admin address of the admin wallet
     * @param upgrader address of the upgrader wallet
     */
    function initialize(address admin, address upgrader) public initializer {
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
     *
     * Does not mint if `to` is the zero address.
     * Reverts if the caller does not have the `TOKEN_BRIDGE_ROLE`.
     * Emits a {CrosschainMint} event.
     */
    function crosschainMint(address to, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        //TODO make a safe transfer
        emit CrosschainMint(to, value, _msgSender());
    }

    /**
     * @dev See {IERC7802-crosschainBurn}.
     * Emits a {CrosschainBurn} event.
     */
    function crosschainBurn(address from, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        //TODO make a safe transfer
        emit CrosschainBurn(from, value, _msgSender());
    }

    /**
     * @dev Authorizes upgrades of the proxy. It can only be called by
     * an account with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}

    //TODO: add a function to get the RLC token address
}
