// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IRLCLiquidityUnifier
 * @dev Interface for the RLC Liquidity Unifier contract.
 *
 * This interface defines the contract that is used to centralize the RLC liquidity
 * across different bridges.
 */
interface IRLCLiquidityUnifier {
    /**
     * @dev Error indicating that the provided 'to' address is invalid for ERC-7802 operations.
     * @param addr The invalid address.
     */
    error ERC7802InvalidToAddress(address addr);

    /**
     * @dev Error indicating that the provided 'from' address is invalid for ERC-7802 operations.
     * @param addr The invalid address.
     */
    error ERC7802InvalidFromAddress(address addr);

    /**
     * @dev Returns the address of the RLC token contract
     * @return The contract address of the RLC token
     */
    function RLC_TOKEN() external view returns (IERC20Metadata);

    /**
     * @dev Returns the number of decimal places used by the token
     * @return The number of decimal places (typically 9 for RLC)
     */
    function decimals() external pure returns (uint8);
}
