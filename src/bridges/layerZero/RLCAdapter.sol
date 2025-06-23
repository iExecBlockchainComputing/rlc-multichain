// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DualPausableUpgradeable} from "../common/DualPausableUpgradeable.sol";

/**
 * @title RLCAdapter
 * @dev A LayerZero OFT Adapter implementation for existing RLC ERC-20 tokens
 *
 * This contract enables cross-chain transfer of existing RLC ERC-20 tokens using LayerZero's OFT Adapter standard.
 * Unlike the bridge which mints/burns tokens, the adapter locks tokens on the source chain and unlocks them
 * when they return from other chains.
 *
 * Cross-chain Transfer Mechanism:
 * 1. When sending tokens FROM this chain: RLC tokens are locked in the adapter contract
 * 2. When receiving tokens TO this chain: Previously locked RLC tokens are unlocked to the recipient
 *
 * ⚠️  IMPORTANT: There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break
 * omnichain unified liquidity by effectively creating separate token pools.
 *
 * Dual-Pause Emergency System:
 * 1. Complete Pause: Blocks all adapter operations (incoming and outgoing transfers)
 * 2. Send Pause: Blocks only outgoing transfers, allows users to receive/withdraw locked funds
 *
 * @custom:security-contact security@iex.ec
 */
contract RLCAdapter is
    OFTAdapterUpgradeable,
    UUPSUpgradeable,
    AccessControlDefaultAdminRulesUpgradeable,
    DualPausableUpgradeable
{
    /// @dev Role identifier for accounts authorized to upgrade the contract
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    /// @dev Role identifier for accounts authorized to pause/unpause the contract
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token, address _lzEndpoint) OFTAdapterUpgradeable(_token, _lzEndpoint) {
        _disableInitializers();
    }

    // ============ INITIALIZATION ============

    /**
     * @notice Initializes the contract after proxy deployment
     * @param _owner Address that will receive owner and default admin roles
     * @param _pauser Address that will receive the pauser role
     */
    // TODO add upgrader role.
    function initialize(address _owner, address _pauser) public initializer {
        __Ownable_init(_owner);
        __OFTAdapter_init(_owner);
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
     * - Users cannot send or receive tokens through the adapter
     * - Use this for critical security incidents (e.g., LayerZero exploit)
     *
     * @custom:security Critical emergency function for complete adapter shutdown
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
     * - _debit operations (outgoing transfers) are blocked
     * - _credit operations (incoming transfers) still work
     * - Users can still receive tokens and withdraw previously locked funds
     * - Use this for less critical issues or when you want to allow withdrawals
     *
     * @custom:security Moderate emergency function allowing users to receive funds while blocking deposits
     */
    function pauseSend() external onlyRole(PAUSER_ROLE) {
        _pauseSend();
    }

    /**
     * @notice LEVEL 2: Unpauses send operations (allows outgoing transfers again)
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpauseSend() external onlyRole(PAUSER_ROLE) {
        _unpauseSend();
    }

    // ============ OVERRIDES ============

    /**
     * @notice Returns the owner address
     * @dev Resolves conflict between OwnableUpgradeable and AccessControlDefaultAdminRulesUpgradeable
     */
    function owner()
        public
        view
        override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }

    /**
     * @notice Internal function to handle outgoing cross-chain transfers
     * @dev This function is called for OUTGOING transfers (when sending to another chain)
     *
     * Pause behavior:
     * - Blocked when contract is fully paused (Level 1 pause)
     * - Blocked when sends are paused (Level 2 pause)
     * - Uses both whenNotPaused and whenSendNotPaused modifiers
     * @param _from Address tokens are being debited from
     * @param _amountLD Amount in local decimals to debit
     * @param _minAmountLD Minimum amount in local decimals to debit
     * @param _dstEid Destination endpoint ID
     * @return amountSentLD Amount sent in local decimals
     * @return amountReceivedLD Amount received in local decimals
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        whenNotPaused
        whenSendNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }

    /**
     * @notice Internal function to handle incoming cross-chain transfers
     * @dev This function is called for INCOMING transfers (when receiving from another chain)
     * Pause behavior:
     * - Blocked ONLY when contract is fully paused (Level 1 pause)
     * - NOT blocked when sends are paused (Level 2) - users can still receive/exit
     * - Uses only whenNotPaused modifier
     * @param _to Address tokens are being credited to
     * @param _amountLD Amount in local decimals to credit
     * @param _srcEid Source endpoint ID
     * @return amountReceivedLD Amount received in local decimals
     */
    function _credit(address _to, uint256 _amountLD, uint32 _srcEid)
        internal
        virtual
        override
        whenNotPaused
        returns (uint256 amountReceivedLD)
    {
        return super._credit(_to, _amountLD, _srcEid);
    }

    /**
     * @notice Authorizes contract upgrades
     * @dev Can only be called by accounts with UPGRADER_ROLE
     * @param newImplementation Address of the new implementation contract
     *
     * @custom:security Ensure proper testing and security review before any upgrade
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {}
}
