// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

/**
 * @title DualPausableUpgradeable
 * @dev Contract module which provides dual pause functionality.
 *
 * This contract implements a two-level pause mechanism:
 * 1. Complete Pause (Level 1): Blocks all operations when activated
 * 2. Entrance Pause (Level 2): Blocks only specific "entrance" operations while allowing "exits"
 *
 * The complete pause takes precedence over entrance pause.
 * - When complete pause is active: ALL operations are blocked
 * - When only entrance pause is active: Only entrance operations are blocked, exits are allowed
 *
 * This is useful for scenarios like:
 * - Complete pause: Critical security incidents requiring full shutdown
 * - Entrance pause: Allow users to withdraw/exit while preventing new entries
 *
 * @custom:storage-location erc7201:iexec.storage.DualPausable
 */
abstract contract DualPausableUpgradeable is PausableUpgradeable {
    /// @custom:storage-location erc7201:iexec.storage.DualPausable
    struct DualPausableStorage {
        /// @dev True when entrance operations are paused, but exit operations are allowed
        bool _entrancesPaused;
    }

    // keccak256(abi.encode(uint256(keccak256("iexec.storage.DualPausable")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant DUAL_PAUSABLE_STORAGE_LOCATION =
        0x8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b900;

    function _getDualPausableStorage() private pure returns (DualPausableStorage storage $) {
        assembly {
            $.slot := DUAL_PAUSABLE_STORAGE_LOCATION
        }
    }

    // ============ EVENTS ============

    /**
     * @dev Emitted when entrance pause is triggered by `account`
     */
    event EntrancePaused(address account);

    /**
     * @dev Emitted when entrance pause is lifted by `account`
     */
    event EntranceUnpaused(address account);

    // ============ ERRORS ============

    /**
     * @dev The operation failed because entrances are paused
     */
    error EnforcedEntrancePause();

    /**
     * @dev The operation failed because entrances are not paused
     */
    error ExpectedEntrancesPause();

    // ============ MODIFIERS ============

    /**
     * @dev Modifier for entrance operations - blocks when fully paused OR when entrances are paused
     */
    modifier whenEntrancesNotPaused() {
        _requireEntrancesNotPaused();
        _;
    }

    /**
     * @dev Modifier to make a function callable only when entrances are paused
     */
    modifier whenEntrancesPaused() {
        _requireEntrancesPaused();
        _;
    }

    // ============ INITIALIZATION ============

    function __DualPausable_init() internal onlyInitializing {
        __Context_init();
        __Pausable_init();
        __DualPausable_init_unchained();
    }

    function __DualPausable_init_unchained() internal onlyInitializing {
        // Initialize entrance pause to false
        // Complete pause is already initialized by PausableUpgradeable
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Returns true if entrances are paused, false otherwise
     */
    function entrancesPaused() public view virtual returns (bool) {
        DualPausableStorage storage $ = _getDualPausableStorage();
        return $._entrancesPaused;
    }

    /**
     * @dev Returns the overall operational state
     * @return fullyPaused True if complete pause is active
     * @return entrancesPaused_ True if entrance pause is active
     * @return fullyOperational True if neither pause is active
     */
    function pauseState()
        public
        view
        virtual
        returns (bool fullyPaused, bool entrancesPaused_, bool fullyOperational)
    {
        fullyPaused = paused();
        entrancesPaused_ = entrancesPaused();
        fullyOperational = !fullyPaused && !entrancesPaused_;
    }

    // ============ INTERNAL FUNCTIONS ============

    /**
     * @dev Throws if entrances are paused or if completely paused
     * Complete pause takes precedence over entrance pause
     */
    function _requireEntrancesNotPaused() internal view virtual {
        // Check complete pause first (takes precedence)
        _requireNotPaused();

        // Then check entrance pause
        if (entrancesPaused()) {
            revert EnforcedEntrancePause();
        }
    }

    /**
     * @dev Throws if entrances are not paused
     */
    function _requireEntrancesPaused() internal view virtual {
        // Check complete pause first (takes precedence)
        _requireNotPaused();

        if (!entrancesPaused()) {
            revert ExpectedEntrancesPause();
        }
    }

    /**
     * @dev Triggers entrance paused state
     * Requirements:
     * - Contract must not be completely paused
     * - Entrances must not already be paused
     */
    function _pauseEntrances() internal virtual whenEntrancesNotPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._entrancesPaused = true;
        emit EntrancePaused(_msgSender());
    }

    /**
     * @dev Returns entrances to normal state
     * Requirements: Entrances must be paused
     */
    function _unpauseEntrances() internal virtual whenEntrancesPaused {
        DualPausableStorage storage $ = _getDualPausableStorage();
        $._entrancesPaused = false;
        emit EntranceUnpaused(_msgSender());
    }

    /**
     * @dev Override to handle entrance pause when completely pausing
     * When pausing completely, we also reset entrance pause since complete pause takes precedence
     */
    function _pause() internal virtual override {
        // First reset entrances if they were paused (complete pause takes precedence)
        DualPausableStorage storage $ = _getDualPausableStorage();
        if ($._entrancesPaused) {
            $._entrancesPaused = false;
            emit EntranceUnpaused(_msgSender());
        }

        // Then pause completely
        super._pause();
    }

    /**
     * @dev Override to handle entrance pause when completely unpausing
     * When unpausing completely, we also unpause entrances to return to fully operational state
     */
    function _unpause() internal virtual override {
        // First unpause entrances if they were paused
        DualPausableStorage storage $ = _getDualPausableStorage();
        if ($._entrancesPaused) {
            $._entrancesPaused = false;
            emit EntranceUnpaused(_msgSender());
        }

        // Then unpause completely
        super._unpause();
    }
}
