// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {IexecLayerZeroBridge} from "../bridges/layerZero/IexecLayerZeroBridge.sol";

/**
 * @title IexecLayerZeroBridgeV2 - V2 implementation with additional features
 * @author IEXEC BLOCKCHAIN TECH
 * @notice This contract inherits from IexecLayerZeroBridge (V1) and adds new functionality
 *
 * @custom:oz-upgrades-from src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge
 */
contract IexecLayerZeroBridgeV2 is IexecLayerZeroBridge {
    // New state variable for v2.
    uint256 public newStateVariable;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(bool approvalRequired, address token, address lzEndpoint)
        IexecLayerZeroBridge(approvalRequired, token, lzEndpoint)
    {}

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
