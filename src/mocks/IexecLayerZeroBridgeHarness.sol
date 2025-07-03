// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IexecLayerZeroBridge} from "../bridges/layerZero/IexecLayerZeroBridge.sol";

contract IexecLayerZeroBridgeHarness is IexecLayerZeroBridge {
    constructor(bool approvalRequired_, address bridgeableToken, address lzEndpoint)
        IexecLayerZeroBridge(approvalRequired_, bridgeableToken, lzEndpoint)
    {}

    function exposed_debit(address from, uint256 amountLD, uint256 minAmountLD, uint32 dstEid)
        external
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        return _debit(from, amountLD, minAmountLD, dstEid);
    }

    function exposed_credit(address to, uint256 amountLD, uint32 srcEid) external returns (uint256 amountReceivedLD) {
        return _credit(to, amountLD, srcEid);
    }
}
