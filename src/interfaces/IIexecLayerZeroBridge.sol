// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

interface IIexecLayerZeroBridge {
    error OperationNotAllowed(string message);

    /**
     * @notice Pauses the contract, disabling `_credit` & `_debit` functions.
     * @dev Should only be callable by authorized accounts: PAUSER_ROLE.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract, re-enabling previously disabled functions (`_credit` & `_debit`).
     * @dev Should only be callable by authorized accounts: PAUSER_ROLE.
     */
    function unpause() external;

    /**
     * @notice Pauses only the `_debit` function, allowing `_credit` to still work.
     * @dev Should only be callable by authorized accounts: PAUSER_ROLE.
     */
    function pauseOutboundTransfers() external;

    /**
     * @notice Unpauses the `_debit` function, allowing outbound transfers again.
     * @dev Should only be callable by authorized accounts: PAUSER_ROLE.
     */
    function unpauseOutboundTransfers() external;
}
