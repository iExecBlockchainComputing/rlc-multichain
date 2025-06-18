// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RLCMock is ERC20 {
    uint256 public constant INITIAL_SUPPLY = 87_000_000 * 10 ** 9; // 87 million tokens with 9 decimals

    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function crosschainMint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function crosschainBurn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}
