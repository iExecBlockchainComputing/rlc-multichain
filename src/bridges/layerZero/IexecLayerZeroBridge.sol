// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTCoreUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {
    AccessControlDefaultAdminRulesUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {DualPausableUpgradeable} from "../utils/DualPausableUpgradeable.sol";
import {IIexecLayerZeroBridge} from "../../interfaces/IIexecLayerZeroBridge.sol";
import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IRLCLiquidityUnifier} from "../../interfaces/IRLCLiquidityUnifier.sol";

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
 * 1. Complete pause: Blocks all bridge operations (inbound and outbound transfers)
 * 2. Only outbout transfers pause: Blocks only outbound transfers, allows users to receive/withdraw funds
 *
 * Architecture Overview:
 * This bridge supports two distinct deployment scenarios:
 *
 * 1. Non-Mainnet Chains (L2s, sidechains, etc.):
 *    - BRIDGEABLE_TOKEN: Points to RLCCrosschain contract (mintable/burnable tokens)
 *    - APPROVAL_REQUIRED: false (bridge can mint/burn directly)
 *    - Mechanism: Mint tokens on transfer-in, burn tokens on transfer-out
 *
 * 2. Ethereum Mainnet:
 *    - BRIDGEABLE_TOKEN: Points to LiquidityUnifier contract (manages original RLC tokens)
 *    - APPROVAL_REQUIRED: true (requires user approval for token transfers)
 *    - Mechanism: Lock tokens on transfer-out, unlock tokens on transfer-in
 *      The LiquidityUnifier contract acts as a relayer, implementing ERC-7802 interface
 *      to provide consistent lock/unlock operations for the original RLC token contract
 *      that may not natively support the crosschain standard.
 */
contract IexecLayerZeroBridge is
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    OFTCoreUpgradeable,
    DualPausableUpgradeable,
    IIexecLayerZeroBridge
{
    using SafeERC20 for IERC20Metadata;

    /// @dev Role identifier for accounts authorized to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Role identifier for accounts authorized to pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    // slither-disable-next-line naming-convention
    address public immutable BRIDGEABLE_TOKEN;

    /**
     * @dev Indicates the token transfer mechanism required for this deployment.
     *
     * - true: Ethereum Mainnet deployment requiring user approval (lock/unlock mechanism)
     * - false: Non Ethereum Mainnet deployment with direct mint/burn capabilities
     *
     * This flag indicates on which chain the bridge is deployed.
     *
     * @custom:oz-upgrades-unsafe-allow state-variable-immutable
     */
    // slither-disable-next-line naming-convention
    bool private immutable APPROVAL_REQUIRED;

    /**
     * @dev Constructor for the LayerZero bridge contract
     * @param bridgeableToken The RLC token contract address that implements IERC7802 interface
     * @param lzEndpoint The LayerZero endpoint address for this chain
     *
     * @custom:oz-upgrades-unsafe-allow constructor
     */
    constructor(bool approvalRequired_, address bridgeableToken, address lzEndpoint)
        OFTCoreUpgradeable(IERC20Metadata(bridgeableToken).decimals(), lzEndpoint)
    {
        _disableInitializers();
        BRIDGEABLE_TOKEN = bridgeableToken;
        APPROVAL_REQUIRED = approvalRequired_;
    }

    // ============ INITIALIZATION ============

    /**
     * @notice Initializes the contract after proxy deployment
     * @param initialAdmin Address that will receive owner and default admin roles
     * @param initialUpgrader Address that will receive the upgrader role
     * @param initialPauser Address that will receive the pauser role
     */
    function initialize(address initialAdmin, address initialUpgrader, address initialPauser) external initializer {
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, initialAdmin);
        _grantRole(UPGRADER_ROLE, initialUpgrader);
        _grantRole(PAUSER_ROLE, initialPauser);
        __Ownable_init(initialAdmin);
        __OFTCore_init(initialAdmin);
        __DualPausable_init();
    }

    // ============ EMERGENCY CONTROLS ============

    /**
     * @notice LEVEL 1: Pauses all cross-chain transfers (complete shutdown)
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When fully paused:
     * - All _debit operations (outbound transfers) are blocked
     * - All _credit operations (inbound transfers) are blocked
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
     * @notice LEVEL 2: Pauses only outbound transfers.
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When outbound transfers are paused:
     * - All _debit operations (outbound transfers) are blocked
     * - All _credit operations (inbound transfers) still work
     * - Users can still receive funds and "exit" their positions
     * - Use this for less critical issues or when you want to allow withdrawals
     *
     * @custom:security Moderate emergency function allowing inbound messages
     * while blocking outbound transfers.
     */
    function pauseOutboundTransfers() external onlyRole(PAUSER_ROLE) {
        _pauseOutboundTransfers();
    }

    /**
     * @notice LEVEL 2: Unpauses outbound transfers (restores send functionality)
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpauseOutboundTransfers() external onlyRole(PAUSER_ROLE) {
        _unpauseOutboundTransfers();
    }

    // ============ OFT CONFIGURATION ============

    /**
     * @notice Indicates whether the OFT contract requires approval to send tokens
     * Approval is only required on the Ethereum Mainnet where the original RLC contract is deployed.
     * @return requiresApproval Returns true if deployed on Ethereum Mainnet, false otherwise
     */
    function approvalRequired() external view virtual returns (bool) {
        return APPROVAL_REQUIRED;
    }

    /**
     * @notice Returns the address of the underlying token being bridged
     * @return The address of the RLC token contract
     */
    function token() external view returns (address) {
        return APPROVAL_REQUIRED ? address(IRLCLiquidityUnifier(BRIDGEABLE_TOKEN).RLC_TOKEN()) : BRIDGEABLE_TOKEN;
    }

    // ============ ACCESS CONTROL OVERRIDES ============

    /**
     * @dev Overridden to prevent ownership renouncement.
     * AccessControlDefaultAdminRulesUpgradeable is used to manage ownership.
     */
    // TODO make this as a non-view function.
    function renounceOwnership() public pure override {
        revert OperationNotAllowed("Use AccessControlDefaultAdminRulesUpgradeable instead");
    }

    /**
     * @dev Overridden to prevent ownership transfer.
     * AccessControlDefaultAdminRulesUpgradeable is used to manage ownership.
     */
    // TODO make this as a non-view function.
    function transferOwnership(address) public pure override {
        revert OperationNotAllowed("Use AccessControlDefaultAdminRulesUpgradeable instead");
    }

    /**
     * Returns the owner of the contract which is also the default admin.
     * @return The address of the current owner and default admin
     */
    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return AccessControlDefaultAdminRulesUpgradeable.owner();
    }

    /**
     * Accepts the default admin transfer and sets the owner to the new admin.
     * @dev This ensures the state variable `OwnableUpgradeable._owner` is set correctly after the default
     * admin transfer. Even though `OwnableUpgradeable._owner` is not used in `owner()` accessor, we chose
     * to update it for consistency purposes.
     */
    function _acceptDefaultAdminTransfer() internal override {
        super._acceptDefaultAdminTransfer();
        _transferOwnership(defaultAdmin());
    }

    // ============ CORE BRIDGE FUNCTIONS ============

    /**
     * Burns tokens from the sender's balance as part of cross-chain transfer
     *
     * @dev This function is called by LayerZero's OFT core when sending tokens
     * to another chain. It burns the specified amount from the sender's balance.
     * It overrides the `_debit` function
     * https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L56-L69
     *
     * This function behavior is chain specific and works differently
     * depending on whether the bridge is deployed on Ethereum Mainnet or a non-mainnet chain.
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token burned = 1 token minted)
     * - If BRIDGEABLE_TOKEN implements transfer fees, burn fees, or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     * @dev This function is called for outbound transfers (when sending to another chain)
     * Pause Behavior:
     * - Blocked when contract is fully paused (Level 1 pause)
     * - Blocked when outbound transfers are paused (Level 2 pause)
     * - Uses both whenNotPaused and whenOutboundTransfersNotPaused modifiers
     *
     * @custom:security Requires the RLC token to have granted burn permissions to this contract
     *
     * @param from The address to burn tokens from
     * @param amountLD The amount of tokens to burn (in local decimals)
     * @param minAmountLD The minimum amount to burn (for slippage protection)
     * @param dstEid The destination chain endpoint ID
     * @return amountSentLD The amount of tokens burned on source chain
     * @return amountReceivedLD The amount that will be minted on destination chain
     */
    function _debit(address from, uint256 amountLD, uint256 minAmountLD, uint32 dstEid)
        internal
        override
        whenNotPaused
        whenOutboundTransfersNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // Calculate the amounts using the parent's logic (handles slippage protection)
        (amountSentLD, amountReceivedLD) = _debitView(amountLD, minAmountLD, dstEid);

        if (APPROVAL_REQUIRED) {
            // Transfer RLC tokens from the user's account to the LiquidityUnifier contract.
            //  The normal workflow would be to call `LiquidityUnifier#crosschainBurn()` but this workflow is not compatible with Stargate UI.
            // Stargate UI does not support approving a contract other than the bridge itself, so here the LiquidityUnifier will not be able to send the `transferFrom` transaction.
            IRLCLiquidityUnifier(BRIDGEABLE_TOKEN).RLC_TOKEN().safeTransferFrom(from, BRIDGEABLE_TOKEN, amountSentLD);
        } else {
            IERC7802(BRIDGEABLE_TOKEN).crosschainBurn(from, amountSentLD);
        }
    }

    /**
     * Mints tokens to the specified account as part of cross-chain transfer.
     *
     * @dev This function is called by LayerZero's OFT core when receiving tokens
     * from another chain. It mints the specified amount to the recipient's balance.
     * It overrides the `_credit` function
     * https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L78-L88
     *
     * This function behavior is chain agnostic and works the same for both chains that does or doesn't require approval.
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token received = 1 token minted)
     * - If BRIDGEABLE_TOKEN implements minting fees or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     *
     * @dev This function is called for inbound transfers (when receiving from another chain)
     * Pause Behavior:
     * - Blocked ONLY when contract is fully paused (Level 1 pause)
     * - NOT blocked when outbound transfers are paused (Level 2) - users can still receive/exit
     * - Uses only whenNotPaused modifier
     *
     * @custom:security Requires the RLC token to have granted mint permissions to this contract
     * @custom:security Uses 0xdead address if _to is zero address (minting to zero fails)
     *
     * @param to The address to mint tokens to
     * @param amountLD The amount of tokens to mint (in local decimals)
     * @return amountReceivedLD The amount of tokens actually minted
     */
    function _credit(
        address to,
        uint256 amountLD,
        uint32 /*_srcEid*/
    )
        internal
        override
        whenNotPaused
        returns (uint256 amountReceivedLD)
    {
        // Handle zero address case - minting to zero address typically fails
        // so we redirect to burn address instead
        if (to == address(0x0)) to = address(0xdead);

        // Mint the tokens to the recipient
        // This assumes crosschainMint doesn't apply any fees
        IERC7802(BRIDGEABLE_TOKEN).crosschainMint(to, amountLD);

        // Return the amount minted (assuming no fees)
        return amountLD;
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
