// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {OFT} from "@layerzerolabs/oft-evm/contracts/OFT.sol";
import {ITokenSpender} from "src/ITokenSpender.sol";

/// @notice OFT is an ERC-20 token that extends the OFTCore contract.
contract RLCOFT is Ownable, OFT {
    constructor(string memory _name, string memory _symbol, address _lzEndpoint, address _delegate)
        Ownable(_delegate)
        OFT(_name, _symbol, _lzEndpoint, _delegate)
    {}

    /**
     * @dev Override the decimals function to return 9 instead of the default 18
     * @return The number of decimals used in the token
     */
    function decimals() public pure override returns (uint8) {
        return 9;
    }

    function burn(uint256 _value) external returns (bool) {
        _burn(msg.sender, _value);
        return true;
    }

    /**
     * Approve and then call the approved contract in a single tx
     */
    function approveAndCall(address _spender, uint256 _value, bytes calldata _extraData) public returns (bool) {
        ITokenSpender spender = ITokenSpender(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, address(this), _extraData);
            return true;
        }
        return false;
    }
}
