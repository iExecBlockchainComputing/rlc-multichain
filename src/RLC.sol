// SPDX-FileCopyrightText: 2024 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.29;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { OFT } from "@layerzerolabs/oft-evm/contracts/OFT.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract RLC is OFT {
    constructor(
            string memory _name,
            string memory _symbol,
            address _lzEndpoint,
            address _delegate
        ) OFT(_name, _symbol, _lzEndpoint, _delegate) Ownable(_delegate) {}
}
