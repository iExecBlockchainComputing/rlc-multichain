// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {ERC20BridgeableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-ERC20BridgeableUpgradeable.sol";
import {ITokenSpender} from "./interfaces/ITokenSpender.sol";

/**
 * This contract is an upgradeable (UUPS) ERC20 token with cross-chain capabilities.
 * It implements the ERC-7802 (https://eips.ethereum.org/EIPS/eip-7802) standard for
 * cross-chain token transfers. It allows minting and burning of tokens as requested
 * by permitted bridge contracts.
 * To whitelist a token bridge contract, the admin (with `DEFAULT_ADMIN_ROLE`) sends
 * a transaction to grant the role `TOKEN_BRIDGE_ROLE` to the bridge contract address
 * using `grantRole` function.
 *
 * TODO upgrade openzeppelin packages when the audited version of ERC20BridgeableUpgradeable
 * is released.
 */
contract RLCCrosschainToken is
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    ERC20PermitUpgradeable,
    ERC20BridgeableUpgradeable
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
     * @param initialAdmin address of the admin wallet
     * @param initialUpgrader address of the upgrader wallet
     */
    function initialize(string memory name, string memory symbol, address initialAdmin, address initialUpgrader)
        public
        initializer
    {
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialUpgrader);
        __ERC20_init(name, symbol);
        __ERC20Permit_init(name);
    }

    /**
     * Approves the spender to spend the specified amount of tokens and calls the `receiveApproval`
     * function on the spender contract. Original code can be found in the RLC token project:
     * https://github.com/iExecBlockchainComputing/rlc-token/blob/master/contracts/RLC.sol#L84-L89
     *
     * @dev The ERC1363 is not used because it is not compatible with the original RLC token contract:
     *  - The RLC uses `receiveApproval` while the ERC1363 uses `onTransferReceived`.
     *  - The PoCo exposes `receiveApproval` in its interface.
     *  - Openzeppelin's implementation of ERC1363 uses Solidity custom errors.
     * This could be changed in the future, but for now, we keep the original interface to insure
     * compatibility with existing Dapps and SDKs.
     *
     * @param spender address of the spender
     * @param value amount of tokens to approve
     * @param data additional data to pass to the spender
     */
    function approveAndCall(address spender, uint256 value, bytes calldata data) external {
        if (approve(spender, value)) {
            ITokenSpender(spender).receiveApproval(msg.sender, value, address(this), data);
        }
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlDefaultAdminRulesUpgradeable, ERC20BridgeableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
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

    /**
     * Checks if the caller is a trusted token bridge that is allowed to call
     * `crosschainMint` or `crosschainBurn` functions.
     * @dev This function is called by the modifier `onlyTokenBridge` in the
     * `ERC20BridgeableUpgradeable` contract.
     * @param caller The address of the caller that is trying to mint or burn tokens.
     */
    function _checkTokenBridge(address caller) internal view override {
        if (!hasRole(TOKEN_BRIDGE_ROLE, caller)) {
            revert IAccessControl.AccessControlUnauthorizedAccount(caller, TOKEN_BRIDGE_ROLE);
        }
    }
}
