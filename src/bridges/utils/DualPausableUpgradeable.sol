// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title DualPausableUpgradeable
 * @dev Abstract contract providing independent pause controls for different operation types.
 *
 * Implements two independent pause mechanisms:
 * 1. Complete pause (inherited from PausableUpgradeable): Blocks ALL operations
 * 2. Outbound transfer pause (new functionality): Blocks only "send" operations while allowing "receive"
 * Emergency Response Scenarios:
 * - Complete pause: Critical security incidents requiring full shutdown
 * - Outbound transfer only pause: Allows inbound requests of already ongoing transfers to complete while
 * preventing new outbound transfers.
 *
 * @custom:storage-location erc7201:iexec.storage.DualPausable
 */
abstract contract DualPausableUpgradeable is PausableUpgradeable {
    // ============ STORAGE ============

    /// @custom:storage-location erc7201:iexec.storage.DualPausable
    struct DualPausableStorage {
        /// @dev True when send operations are paused, but receive operations are allowed.
        bool _outboundTransfersPaused;
    }

    /// keccak256(abi.encode(uint256(keccak256("iexec.storage.DualPausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DUAL_PAUSABLE_STORAGE_LOCATION =
        0xcfbc5ec03206ba5826cf1103520b82c735e9bad14c6d8ed92dff9144ead3f400;

    function _getDualPausableStorage() private pure returns (DualPausableStorage storage $) {
        //slither-disable-next-line assembly
        assembly {
            $.slot := DUAL_PAUSABLE_STORAGE_LOCATION
        }
    }

    // ============ EVENTS ============

    /**
     * @dev Emitted when outbount transfer pause is triggered by `account`
     */
    event OutboundTransfersPaused(address account);

    /**
     * @dev Emitted when outbount transfer pause is lifted by `account`
     */
    event OutboundTransfersUnpaused(address account);

    // ============ ERRORS ============

    /**
     * @dev The operation failed because send operations are paused
     */
    error EnforcedOutboundTransfersPause();

    /**
     * @dev The operation failed because send operations are not paused
     */
    error ExpectedOutboundTransfersPause();

    // ============ MODIFIERS ============

    /**
     * @dev Modifier for send operations - blocks when outbount transfer is paused
     * @notice Use this modifier for functions that should be blocked during outbount transfer pause
     */
    modifier whenOutboundTransfersNotPaused() {
        _requireOutbountTransfersNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when send operations are paused
     * @notice Use this modifier for administrative functions that should only work during outbount transfer pause
     */
    modifier whenOutbountTransfersPaused() {
        _requireOutbountTransfersPaused();
        _;
    }

    // ============ INITIALIZATION ============

    //slither-disable-next-line naming-convention
    function __DualPausable_init() internal onlyInitializing {
        __Pausable_init();
    }

    //slither-disable-start naming-convention
    //slither-disable-start dead-code
    function __DualPausable_init_unchained() internal onlyInitializing {}
    //slither-disable-end naming-convention
    //slither-disable-end dead-code

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns true if send operations are paused, false otherwise
     */
    function outbountTransfersPaused() public view virtual returns (bool) {
        DualPausableStorage storage $ = _getDualPausableStorage();
        return $._outboundTransfersPaused;
    }

    /**
     * @dev Returns the overall operational state of the contract
     * @return fullyPaused True if complete pause is active (blocks all operations)
     * @return onlyOutboundTransfersPaused True if outbount transfer pause is active (blocks only send operations)
     */
    function pauseStatus() public view virtual returns (bool fullyPaused, bool onlyOutboundTransfersPaused) {
        fullyPaused = paused();
        onlyOutboundTransfersPaused = outbountTransfersPaused();
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Throws if send operations are paused
     */
    function _requireOutbountTransfersNotPaused() internal view virtual {
        if (outbountTransfersPaused()) {
            revert EnforcedOutboundTransfersPause();
        }
    }

    /**
     * @dev Throws if send operations are not paused
     */
    function _requireOutbountTransfersPaused() internal view virtual {
        if (!outbountTransfersPaused()) {
            revert ExpectedOutboundTransfersPause();
        }
    }

    /**
     * @dev Triggers outbount transfers pause.
     * Requirements:
     * - Send operations must not already be paused
     */
    function _pauseOutboundTransfers() internal virtual whenOutboundTransfersNotPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._outboundTransfersPaused = true;
        emit OutboundTransfersPaused(_msgSender());
    }

    /**
     * @dev Unpauses outbount transfers.
     * Requirements:
     * - Send operations must already be paused
     */
    function _unpauseOutboundTransfers() internal virtual whenOutbountTransfersPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._outboundTransfersPaused = false;
        emit OutboundTransfersUnpaused(_msgSender());
    }
}
