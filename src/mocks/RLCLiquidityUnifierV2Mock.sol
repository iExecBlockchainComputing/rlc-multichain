// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {RLCLiquidityUnifier} from "../RLCLiquidityUnifier.sol";

/**
 * @title RLCLiquidityUnifierV2 - V2 implementation with additional features
 * @author IEXEC BLOCKCHAIN TECH
 * @notice This contract inherits from RLCLiquidityUnifier (V1) and adds new functionality
 *
 * @custom:oz-upgrades-from src/RLCLiquidityUnifier.sol:RLCLiquidityUnifier
 */
contract RLCLiquidityUnifierV2 is RLCLiquidityUnifier {
    /// New state variable for v2.
    uint256 public newStateVariable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _token) RLCLiquidityUnifier(_token) {}

    /**
     * @notice Initializes V2 features (called after upgrade)
     * @param _newStateVariable New state variable description
     *
     * @custom:oz-upgrades-validate-as-initializer
     */
    function initializeV2(uint256 _newStateVariable) public reinitializer(2) {
        newStateVariable = _newStateVariable;
    }
}
