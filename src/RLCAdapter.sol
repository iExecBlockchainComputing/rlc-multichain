// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapterUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTAdapterUpgradeable.sol";
import {AccessControlDefaultAdminRulesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlDefaultAdminRulesUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {DualPausableUpgradeable} from "./DualPausableUpgradeable.sol";

/**
 * @title RLCAdapter
 * @dev A LayerZero OFT Adapter implementation for existing RLC ERC-20 tokens
 *
 * This contract enables cross-chain transfer of existing RLC ERC-20 tokens using LayerZero's OFT Adapter standard.
 * Unlike the bridge which mints/burns tokens, the adapter locks tokens on the source chain and unlocks them
 * when they return from other chains.
 *
 * It implements a cross-chain transfer mechanism where:
 * 1. When sending tokens FROM this chain: RLC tokens are locked in the adapter contract
 * 2. When receiving tokens TO this chain: Previously locked RLC tokens are unlocked to the recipient
 *
 * ⚠️  IMPORTANT: There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break 
 * omnichain unified liquidity by effectively creating separate token pools.
 *
 * It implements a dual-pause mechanism:
 * 1. Complete Pause: Blocks all adapter operations (incoming and outgoing transfers)
 * 2. Entrance Pause: Blocks only outgoing transfers, allows users to receive/withdraw locked funds
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
     *
     * Use this for critical security incidents requiring immediate complete shutdown.
     */
    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @notice Unpauses all operations (returns to fully operational state)
     * @dev Can only be called by accounts with PAUSER_ROLE
     * @dev Automatically resets entrance pause if it was active
     */
    function unpause() external onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @notice LEVEL 2: Pauses only outgoing transfers (entrance pause)
     * @dev Can only be called by accounts with PAUSER_ROLE
     *
     * When entrance paused:
     * - _debit operations (outgoing transfers) are blocked
     * - _credit operations (incoming transfers) continue to work
     * - Users can still receive tokens and withdraw previously locked funds
     *
     * Use this when you want to stop new outgoing transfers while allowing users
     * to receive funds and withdraw locked tokens.
     */
    function pauseEntrances() external onlyRole(PAUSER_ROLE) {
        _pauseEntrances();
    }

    /**
     * @notice Unpauses entrance operations (allows outgoing transfers again)
     * @dev Can only be called by accounts with PAUSER_ROLE
     */
    function unpauseEntrances() external onlyRole(PAUSER_ROLE) {
        _unpauseEntrances();
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
     * @dev Overridden to implement dual-pause logic
     * 
     * Pause behavior:
     * - Complete pause: Blocks all operations
     * - Entrance pause: Blocks only this operation (outgoing transfers)
     * - Operational: Allows all operations
     *
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
        whenEntrancesNotPaused
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        return super._debit(_from, _amountLD, _minAmountLD, _dstEid);
    }

    /**
     * @notice Internal function to handle incoming cross-chain transfers
     * @dev Overridden to implement pause logic
     * 
     * Pause behavior:
     * - Complete pause: Blocks all operations
     * - Entrance pause: Allows this operation (incoming transfers)
     * - Operational: Allows all operations
     *
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
