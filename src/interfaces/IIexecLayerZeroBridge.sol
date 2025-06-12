// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {IOFT} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";

interface IIexecLayerZeroBridge is IOFT {
    function pause() external;

    function unpause() external;
}
