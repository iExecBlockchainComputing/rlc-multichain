// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTCoreUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {DualPausableUpgradeable} from "../common/DualPausableUpgradeable.sol";
import {IIexecLayerZeroBridge} from "../../interfaces/IIexecLayerZeroBridge.sol";
import {IERC7802} from "../../interfaces/IERC7802.sol";

/**
 * @title IexecLayerZeroBridge
 * @dev A LayerZero OFT (Omnichain Fungible Token) bridge implementation for RLC tokens
 *
 * This contract enables cross-chain transfer of RLC tokens using LayerZero's OFT standard.
 * It overrides the `_debit` and `_credit` functions to use external mint and burn functions
 * on the CrosschainRLC token contract.
 *
 * Cross-chain Transfer Mechanism:
 * 1. When sending tokens FROM this chain: RLC tokens are permanently burned from the sender's balance
 * 2. When receiving tokens TO this chain: New RLC tokens are minted to the recipient's balance
 *
 * This ensures the total supply across all chains remains constant - tokens destroyed on one
 * chain are minted on another, maintaining a 1:1 peg across the entire ecosystem.
 *
 * Dual-Pause Emergency System:
 * 1. Complete Pause: Blocks all bridge operations (incoming and outgoing transfers)
 * 2. Send Pause: Blocks only outgoing transfers, allows users to receive/withdraw funds
 */
contract IexecLayerZeroBridge is
    IIexecLayerZeroBridge,
    OFTCoreUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    DualPausableUpgradeable
{
    /// @dev Role identifier for accounts authorized to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Role identifier for accounts authorized to pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev The RLC token contract that this bridge operates on
     * Must implement the [ERC-7802](https://eips.ethereum.org/EIPS/eip-7802) interface.
     *
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    IERC7802 public immutable BRIDGEABLE_TOKEN;

    /**
     * @dev Constructor for the LayerZero bridge contract
     * @param _bridgeableToken The RLC token contract address that implements IERC7802 interface
     * @param _lzEndpoint The LayerZero endpoint address for this chain
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(address _bridgeableToken, address _lzEndpoint)
        OFTCoreUpgradeable(IERC20Metadata(_bridgeableToken).decimals(), _lzEndpoint)
    {
        _disableInitializers();
        BRIDGEABLE_TOKEN = IERC7802(_bridgeableToken);
    }

    // ============ INITIALIZATION ============

    /**
     * @notice Initializes the contract after proxy deployment
     * @param _owner Address that will receive owner and default admin roles
     * @param _pauser Address that will receive the pauser role
     */
    // TODO add upgrader role.
    function initialize(address _owner, address _pauser) external initializer {
        __Ownable_init(_owner);
        __OFTCore_init(_owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        __DualPausable_init();
        _grantRole(UPGRADER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
    }

    // ============ EMERGENCY CONTROLS ============

    /**
     * @notice LEVEL 1: Pauses all cross-chain transfers (complete shutdown)
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When fully paused:
     * - All _debit operations (outgoing transfers) are blocked
     * - All _credit operations (incoming transfers) are blocked
     * - Use this for critical security incidents (e.g., LayerZero exploit)
     *
     * @custom:security Critical emergency function for complete bridge shutdown
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice LEVEL 1: Unpauses all cross-chain transfers
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice LEVEL 2: Pauses only outgoing transfers (send pause)
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When send is paused:
     * - All _debit operations (outgoing transfers) are blocked
     * - All _credit operations (incoming transfers) still work
     * - Users can still receive funds and "exit" their positions
     * - Use this for less critical issues or when you want to allow withdrawals
     *
     * @custom:security Moderate emergency function allowing exits while blocking send
     */
    function pauseSend() external onlyRole(PAUSER_ROLE) {
        _pauseSend();
    }

    /**
     * @notice LEVEL 2: Unpauses outgoing transfers (restores send functionality)
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpauseSend() external onlyRole(PAUSER_ROLE) {
        _unpauseSend();
    }

    // ============ OFT CONFIGURATION ============

    /**
     * @notice Indicates whether the OFT contract requires approval to send tokens
     * @return requiresApproval Returns true if deployed on Ethereum Mainnet, false otherwise
     */
    function approvalRequired() external view virtual returns (bool) {
        return block.chainid == 1;
    }

    /**
     * @notice Returns the address of the underlying token being bridged
     * @return The address of the RLC token contract
     */
    function token() external view returns (address) {
        return address(BRIDGEABLE_TOKEN);
    }

    // ============ ACCESS CONTROL OVERRIDES ============

    /**
     * @notice Returns the owner of the contract
     * @return The address of the current owner
     *
     * @dev This override resolves the conflict between OwnableUpgradeable and
     * AccessControlDefaultAdminRulesUpgradeable, both of which define owner().
     * We use the OwnableUpgradeable version for consistency.
     */
    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    // ============ CORE BRIDGE FUNCTIONS ============

    /**
     * @notice Burns tokens from the sender's balance as part of cross-chain transfer
     * @param _from The address to burn tokens from
     * @param _amountLD The amount of tokens to burn (in local decimals)
     * @param _minAmountLD The minimum amount to burn (for slippage protection)
     * @param _dstEid The destination chain endpoint ID
     * @return amountSentLD The amount of tokens burned on source chain
     * @return amountReceivedLD The amount that will be minted on destination chain
     *
     * @dev This function is called by LayerZero's OFT core when sending tokens
     * to another chain. It burns the specified amount from the sender's balance.
     * It overrides the `_debit` function
     * https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L56-L69
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token burned = 1 token minted)
     * - If BRIDGEABLE_TOKEN implements transfer fees, burn fees, or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     * @dev This function is called for OUTGOING transfers (when sending to another chain)
     * Pause Behavior:
     * - Blocked when contract is fully paused (Level 1 pause)
     * - Blocked when sends are paused (Level 2 pause)
     * - Uses both whenNotPaused and whenSendNotPaused modifiers
     *
     * @custom:security Requires the RLC token to have granted burn permissions to this contract
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        override
        whenNotPaused
        whenSendNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // Calculate the amounts using the parent's logic (handles slippage protection)
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // Burn the tokens from the sender's balance
        BRIDGEABLE_TOKEN.crosschainBurn(_from, amountSentLD);
    }

    /**
     * @notice Mints tokens to the specified account as part of cross-chain transfer.
     * @param _to The address to mint tokens to
     * @param _amountLD The amount of tokens to mint (in local decimals)
     * @return amountReceivedLD The amount of tokens actually minted
     *
     * @dev This function is called by LayerZero's OFT core when receiving tokens
     * from another chain. It mints the specified amount to the recipient's balance.
     * It overrides the `_credit` function
     * https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L78-L88
     *
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token received = 1 token minted)
     * - If BRIDGEABLE_TOKEN implements minting fees or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     *
     * @dev This function is called for INCOMING transfers (when receiving from another chain)
     * Pause Behavior:
     * - Blocked ONLY when contract is fully paused (Level 1 pause)
     * - NOT blocked when sends are paused (Level 2) - users can still receive/exit
     * - Uses only whenNotPaused modifier
     *
     * @custom:security Requires the RLC token to have granted mint permissions to this contract
     * @custom:security Uses 0xdead address if _to is zero address (minting to zero fails)
     */
    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/ )
        internal
        override
        whenNotPaused
        returns (uint256 amountReceivedLD)
    {
        // Handle zero address case - minting to zero address typically fails
        // so we redirect to burn address instead
        if (_to == address(0x0)) _to = address(0xdead);

        // Mint the tokens to the recipient
        // This assumes crosschainMint doesn't apply any fees
        BRIDGEABLE_TOKEN.crosschainMint(_to, _amountLD);

        // Return the amount minted (assuming no fees)
        return _amountLD;
    }

    // ============ UPGRADE AUTHORIZATION ============

    /**
     * @notice Authorizes contract upgrades
     * @param newImplementation The address of the new implementation contract
     *
     * @dev This function is required by UUPS upgradeable pattern.
     * Only accounts with UPGRADER_ROLE can authorize upgrades.
     *
     * @custom:security Critical function that controls contract upgrades
     * @custom:security Ensure proper testing and security review before any upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
