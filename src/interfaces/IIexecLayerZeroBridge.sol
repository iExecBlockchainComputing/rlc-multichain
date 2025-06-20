// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

interface IIexecLayerZeroBridge {
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
    function pauseSend() external;

    /**
     * @notice Unpauses the `_debit` function, allowing outgoing transfers again.
     * @dev Should only be callable by authorized accounts: PAUSER_ROLE.
     */
    function unpauseSend() external;
}
