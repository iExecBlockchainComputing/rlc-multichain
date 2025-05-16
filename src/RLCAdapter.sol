// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {OFTAdapter} from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
contract RLCAdapter is Ownable, OFTAdapter {
    constructor(address _token, address _lzEndpoint, address _owner)
        Ownable(_owner)
        OFTAdapter(_token, _lzEndpoint, _owner)
    {}
}
