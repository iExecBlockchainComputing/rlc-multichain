// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IRLC} from "./interfaces/IRLC.sol";
import {OFTCoreUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {IIexecLayerZeroBridge} from "./interfaces/IIexecLayerZeroBridge.sol";

/**
 * @title IexecLayerZeroBridge
 * @dev A LayerZero OFT (Omnichain Fungible Token) bridge implementation for RLC tokens
 *
 * This contract enables cross-chain transfer of RLC tokens using LayerZero's OFT standard.
 * It implements a cross-chain transfer mechanism where:
 * 1. When sending tokens FROM this chain: RLC tokens are permanently burned from the sender's balance
 * 2. When receiving tokens TO this chain: New RLC tokens are minted to the recipient's balance
 *
 * This ensures the total supply across all chains remains constant - tokens destroyed on one
 * chain are recreated on another, maintaining a 1:1 peg across the entire ecosystem.
 */
contract IexecLayerZeroBridge is
    IIexecLayerZeroBridge,
    OFTCoreUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    PausableUpgradeable
{
    /// @dev Role identifier for accounts authorized to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Role identifier for accounts authorized to pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev The RLC token contract that this bridge operates on
     * @notice This is immutable and set during contract deployment
     * Must implement the IRLC interface with crosschainBurn and crosschainMint functions
     */
    IRLC public immutable RLC_Token;

    /**
     * @dev Constructor for the LayerZero bridge contract
     * @param _token The RLC token contract address that implements IRLC interface
     * @param _lzEndpoint The LayerZero endpoint address for this chain
     *
     * @notice The constructor sets up the immutable references and disables initializers
     * to prevent the implementation contract from being initialized directly.
     * Actual initialization happens through the initialize() function after proxy deployment.
     */
    constructor(IRLC _token, address _lzEndpoint) OFTCoreUpgradeable(_token.decimals(), _lzEndpoint) {
        _disableInitializers();
        RLC_Token = _token;
    }

    // ============ INITIALIZATION ============

    /**
     * @notice Initializes the contract after proxy deployment
     * @param _owner Address that will receive owner and default admin roles
     * @param _pauser Address that will receive the pauser role
     *
     * @dev This function can only be called once due to the initializer modifier.
     * It sets up all the inherited contracts and grants the necessary roles.
     *
     * Roles granted:
     * - _owner: Gets owner role, default admin role, and upgrader role
     * - _pauser: Gets pauser role for emergency controls
     */
    function initialize(address _owner, address _pauser) public initializer {
        __Ownable_init(_owner);
        __OFTCore_init(_owner);
        __UUPSUpgradeable_init();
        __AccessControlDefaultAdminRules_init(0, _owner);
        __Pausable_init();
        _grantRole(UPGRADER_ROLE, _owner);
        _grantRole(PAUSER_ROLE, _pauser);
    }

    // ============ OFT CONFIGURATION ============

    /**
     * @notice Indicates whether the OFT contract requires approval to send tokens
     * @return requiresApproval Always returns false for this implementation
     *
     * @dev This contract uses a burn/mint mechanism where it directly calls
     * crosschainBurn on the RLC token contract, so no approval is required.
     * The bridge has the necessary permissions to burn tokens directly.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /**
     * @notice Returns the address of the underlying token being bridged
     * @return The address of the RLC token contract
     *
     * @dev This function is required by the OFT standard to identify
     * which token is being bridged across chains
     */
    function token() public view returns (address) {
        return address(RLC_Token);
    }

    // ============ EMERGENCY CONTROLS ============

    /**
     * @notice Pauses all cross-chain transfers
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When paused:
     * - All _debit operations (outgoing transfers) are blocked
     * - All _credit operations (incoming transfers) are blocked
     * - Emergency measure to halt all bridge activity if needed
     *
     * @custom:security This is a critical emergency function that should only
     * be used in case of security incidents or other emergencies
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all cross-chain transfers
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * @notice This will resume normal bridge operations after a pause
     * Ensure any issues that caused the pause have been resolved before calling
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
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
     * @notice Burns tokens on the source chain as part of cross-chain transfer
     * @param _from The address to burn tokens from
     * @param _amountLD The amount of tokens to burn (in local decimals)
     * @param _minAmountLD The minimum amount to burn (for slippage protection)
     * @param _dstEid The destination chain endpoint ID
     * @return amountSentLD The amount of tokens burned on source chain
     * @return amountReceivedLD The amount that will be minted on destination chain
     *
     * @dev This function is called by LayerZero's OFT core when sending tokens
     * to another chain. It burns the specified amount from the sender's balance.
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token burned = 1 token minted)
     * - If RLC_Token implements transfer fees, burn fees, or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     *
     * @custom:security Only callable when contract is not paused
     * @custom:security Requires the RLC token to have granted burn permissions to this contract
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        whenNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        // Calculate the amounts using the parent's logic (handles slippage protection)
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // Burn the tokens from the sender's balance
        // This assumes crosschainBurn doesn't apply any fees
        RLC_Token.crosschainBurn(_from, amountSentLD);
    }

    /**
     * @notice Mints tokens to the specified account as part of cross-chain transfer.
     * @param _to The address to mint tokens to
     * @param _amountLD The amount of tokens to mint (in local decimals)
     * @return amountReceivedLD The amount of tokens actually minted
     *
     * @dev This function is called by LayerZero's OFT core when receiving tokens
     * from another chain. It mints the specified amount to the recipient's balance.
     *
     * IMPORTANT ASSUMPTIONS:
     * - This implementation assumes LOSSLESS transfers (1 token received = 1 token minted)
     * - If RLC_Token implements minting fees or any other fee mechanism,
     *   this function will NOT work correctly and would need to be modified
     * - The function would need pre/post balance checks to handle fee scenarios
     *
     * @custom:security Only callable when contract is not paused
     * @custom:security Requires the RLC token to have granted mint permissions to this contract
     * @custom:security Uses 0xdead address if _to is zero address (minting to zero address fails)
     */
    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        whenNotPaused
        returns (uint256 amountReceivedLD)
    {
        // Handle zero address case - minting to zero address typically fails
        // so we redirect to burn address instead
        if (_to == address(0x0)) _to = address(0xdead);

        // Mint the tokens to the recipient
        // This assumes crosschainMint doesn't apply any fees
        RLC_Token.crosschainMint(_to, _amountLD);

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
