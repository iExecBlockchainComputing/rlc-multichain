// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * Simulates the RLC token behavior for testing purposes.
 * Cannot directly import the original RLC contract because of solidity version mismatch.
 * Don't use OZ ERC20 as the implementation differs:
 * - The RLC does not revert when transferring to the zero address.
 * - The RLC reverts with arithmetic panic error instead of ERC20InsufficientAllowance (for e.g.).
 */
contract RLCMock is IERC20 {
    uint256 public totalSupply;
    mapping(address => uint) balances;
    mapping(address => mapping(address => uint)) allowed;

    constructor() {
        totalSupply = 87_000_000 * 10 ** 9; // 87 million tokens with 9 decimals
        balances[msg.sender] = totalSupply;
    }

    // Does not check the to address.
    // Reverts with arithmetic panic error for balance issues.
    function transfer(address to, uint256 value) external returns (bool) {
        balances[msg.sender] = balances[msg.sender] - value;
        balances[to] = balances[to] + value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    // Does not check the from and to addresses.
    // Reverts with arithmetic panic error for allowance issues.
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 _allowance = allowed[from][msg.sender];
        balances[to] = balances[to] + value;
        balances[from] = balances[from] - value;
        allowed[from][msg.sender] = _allowance - value;
        emit Transfer(from, to, value);
        return true;
    }

    // Does not check the spender address.
    function approve(address spender, uint value) external override returns (bool) {
        allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function decimals() public pure returns (uint8) {
        return 9;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) external view override returns (uint256) {
        return allowed[owner][spender];
    }
}
