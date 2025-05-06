
// SPDX-FileCopyrightText: 2024 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.29;

import { OFTAdapter } from "@layerzerolabs/oft-evm/contracts/OFTAdapter.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @notice OFTAdapter uses a deployed ERC-20 token and safeERC20 to interact with the OFTCore contract.
// There can only be one OFT Adapter deployed per chain. Multiple OFT Adapters break omnichain unified 
// liquidity by effectively creating token pools.
contract RLCAdapter is OFTAdapter {
    constructor(
            address _token,
            address _lzEndpoint,
            address _owner
        ) OFTAdapter(_token, _lzEndpoint, _owner) Ownable(_owner) {}

        //TODO: check the decimal: https://docs.layerzero.network/v2/developers/evm/oft/quickstart#token-supply-cap

        
}
