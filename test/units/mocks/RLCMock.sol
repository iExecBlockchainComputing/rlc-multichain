// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract RLCMock is ERC20 {
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}

    function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
