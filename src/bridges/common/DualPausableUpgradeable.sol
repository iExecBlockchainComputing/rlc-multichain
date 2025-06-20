// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title DualPausableUpgradeable
 * @dev Abstract contract providing independent pause controls for different operation types.
 *
 * Implements two independent pause mechanisms:
 * 1. Complete Pause (inherited from PausableUpgradeable): Blocks ALL operations
 * 2. Send Pause (new functionality): Blocks only "send" operations while allowing "receive"
 * Emergency Response Scenarios:
 * - Complete pause: Critical security incidents requiring full shutdown
 * - Send pause: Allows ongoing transfers to complete while preventing new outgoing transfers
 *
 * @custom:storage-location erc7201:iexec.storage.DualPausable
 */
abstract contract DualPausableUpgradeable is PausableUpgradeable {
    // ============ STORAGE ============

    /// @custom:storage-location erc7201:iexec.storage.DualPausable
    struct DualPausableStorage {
        /// @dev True when send operations are paused, but receive operations are allowed.
        bool _sendPaused;
    }

    // keccak256(abi.encode(uint256(keccak256("iexec.storage.DualPausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DUAL_PAUSABLE_STORAGE_LOCATION =
        0xcfbc5ec03206ba5826cf1103520b82c735e9bad14c6d8ed92dff9144ead3f400;

    function _getDualPausableStorage() private pure returns (DualPausableStorage storage $) {
        assembly {
            $.slot := DUAL_PAUSABLE_STORAGE_LOCATION
        }
    }

    // ============ EVENTS ============

    /**
     * @dev Emitted when send pause is triggered by `account`
     */
    event SendPaused(address account);

    /**
     * @dev Emitted when send pause is lifted by `account`
     */
    event SendUnpaused(address account);

    // ============ ERRORS ============

    /**
     * @dev The operation failed because send operations are paused
     */
    error EnforcedSendPause();

    /**
     * @dev The operation failed because send operations are not paused
     */
    error ExpectedSendPause();

    // ============ MODIFIERS ============

    /**
     * @dev Modifier for send operations - blocks when send is paused
     * @notice Use this modifier for functions that should be blocked during send pause
     */
    modifier whenSendNotPaused() {
        _requireSendNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when send operations are paused
     * @notice Use this modifier for administrative functions that should only work during send pause
     */
    modifier whenSendPaused() {
        _requireSendPaused();
        _;
    }

    // ============ INITIALIZATION ============

    function __DualPausable_init() internal onlyInitializing {
        __Pausable_init();
    }

    function __DualPausable_init_unchained() internal onlyInitializing {}
    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns true if send operations are paused, false otherwise
     */
    function sendPaused() public view virtual returns (bool) {
        DualPausableStorage storage $ = _getDualPausableStorage();
        return $._sendPaused;
    }

    /**
     * @dev Returns the overall operational state of the contract
     * @return fullyPaused True if complete pause is active (blocks all operations)
     * @return sendPausedOnly True if send pause is active (blocks only send operations)
     */
    function pauseStatus() public view virtual returns (bool fullyPaused, bool sendPausedOnly) {
        fullyPaused = paused();
        sendPausedOnly = sendPaused();
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Throws if send operations are paused
     */
    function _requireSendNotPaused() internal view virtual {
        if (sendPaused()) {
            revert EnforcedSendPause();
        }
    }

    /**
     * @dev Throws if send operations are not paused
     */
    function _requireSendPaused() internal view virtual {
        if (!sendPaused()) {
            revert ExpectedSendPause();
        }
    }

    /**
     * @dev Triggers send paused state
     * Requirements:
     * - Send operations must not already be paused
     */
    function _pauseSend() internal virtual whenSendNotPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._sendPaused = true;
        emit SendPaused(_msgSender());
    }

    /**
     * @dev Returns send operations to normal state
     * Requirements:
     * - Send operations must currently be paused
     */
    function _unpauseSend() internal virtual whenSendPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._sendPaused = false;
        emit SendUnpaused(_msgSender());
    }
}
