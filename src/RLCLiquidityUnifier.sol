// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IRLCLiquidityUnifier} from "./interfaces/IRLCLiquidityUnifier.sol";

/**
 * @dev This contract facilitates cross-chain liquidity unification by allowing
 * the minting and burning of tokens on the RLC token contract. All bridges
 * should interact with this contract to perform RLC transfers.
 *
 * The implementation is inspired by the OpenZeppelin ERC20Bridgeable contract
 * without being an ERC20 token itself. Functions are overridden to lock/unlock
 * tokens on an external ERC20 contract. ERC20Bridgeable is not used directly
 * because it embarks the ERC20 token logic, which is not needed here.
 */
contract RLCLiquidityUnifier is
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    IRLCLiquidityUnifier,
    IERC7802
{
    using SafeERC20 for IERC20Metadata;

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    // slither-disable-next-line naming-convention
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
     * @param initialAdmin address of the admin wallet
     * @param initialUpgrader address of the upgrader wallet
     */
    function initialize(address initialAdmin, address initialUpgrader) public initializer {
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialUpgrader);
    }

    // ============ CROSS-CHAIN FUNCTIONS ============
    /**
     * @dev See {IERC7802-crosschainMint}.
     *
     * Unlocks RLC tokens from this contract's balance and transfers them to the recipient.
     * This function is called when tokens are being received from another chain via the bridge.
     * Emits a {CrosschainMint} event indicating tokens were unlocked for cross-chain transfer.
     *
     * Cross-chain flow:
     * 1. Tokens are burned/locked on the source chain.
     * 2. The bridge calls this function to unlock the equivalent tokens amount on the destination chain.
     * 3. Tokens are transferred from this contract's balance to the recipient.
     *
     * Requirements:
     * - Caller must have TOKEN_BRIDGE_ROLE (typically the LayerZero bridge contract)
     * - Contract must have sufficient RLC token balance to fulfill the transfer
     * - `to` address must be valid (non-zero)
     *
     * @custom:security Only authorized bridge contracts can call this function
     *
     * @param to The address to receive the unlocked RLC tokens
     * @param value The amount of RLC tokens to unlock and transfer
     */
    function crosschainMint(address to, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        // The RLC contract does not check for zero addresses.
        if (to == address(0)) {
            revert ERC7802InvalidToAddress(address(0));
        }
        // Re-entrancy safe because the RLC contract is controlled and does not make external calls.
        RLC_TOKEN.safeTransfer(to, value);
        emit CrosschainMint(to, value, _msgSender());
    }

    /**
     * @dev See {IERC7802-crosschainBurn}.
     *
     * Locks RLC tokens by transferring them from the sender to this contract's reserve.
     * This function is called when tokens are being sent to another chain via the bridge.
     * Emits a {CrosschainBurn} event indicating tokens were locked for cross-chain transfer.
     *
     * Cross-chain flow:
     * 1. The user approves this contract to spend RLC tokens on their behalf.
     * 2. The user initiates a cross-chain transfer through the bridge.
     * 3. The bridge calls this function to lock tokens on the source chain.
     * 4. Tokens are transferred from the sender's account to this contract (locked).
     *
     * Requirements:
     * - Caller must have TOKEN_BRIDGE_ROLE (typically the LayerZero bridge contract)
     * - `from` address must have approved this contract to spend at least `value` tokens
     * - `from` address must have sufficient RLC token balance
     *
     * @custom:security Only authorized bridge contracts can call this function
     *
     * @param from The address to lock RLC tokens from (must have approved this contract)
     * @param value The amount of RLC tokens to lock in this contract
     */
    // slither-disable-next-line arbitrary-send-erc20
    function crosschainBurn(address from, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE) {
        // The RLC contract does not check for zero addresses.
        if (from == address(0)) {
            revert ERC7802InvalidFromAddress(address(0));
        }
        // Re-entrancy safe because the RLC contract is controlled and does not make external calls.
        RLC_TOKEN.safeTransferFrom(from, address(this), value);
        emit CrosschainBurn(from, value, _msgSender());
    }

    // ============ FOR LAYERZERO BRIDGE ============
    /**
     * @notice Returns the number of decimal places used by the underlying RLC token
     * @return The decimal places of the RLC token (typically 9 for RLC)
     *
     * @dev This function provides LayerZero bridge compatibility by exposing the decimal
     * precision of the underlying RLC token. LayerZero's OFT (Omnichain Fungible Token)
     * standard requires this information to properly handle token amounts across different
     * chains with potentially different decimal representations.
     *
     * @custom:bridge-compatibility Required by LayerZero OFT standard
     */
    function decimals() external pure returns (uint8) {
        return 9;
    }

    // ============ FOR ERC165 INTERFACE DETECTION ============
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlDefaultAdminRulesUpgradeable, IERC165)
        returns (bool)
    {
        return interfaceId == type(IERC7802).interfaceId || super.supportsInterface(interfaceId);
    }

    // ============ FOR UUPS UPGRADES ============
    /**
     * @dev Authorizes upgrades of the proxy. It can only be called by
     * an account with the UPGRADER_ROLE.
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
