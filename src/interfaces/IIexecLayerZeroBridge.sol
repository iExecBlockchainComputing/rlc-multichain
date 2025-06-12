// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

interface IIexecLayerZeroBridge is IOFT {
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
}
