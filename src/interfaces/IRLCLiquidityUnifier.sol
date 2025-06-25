// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

import {IERC7802} from "@openzeppelin/contracts/interfaces/draft-IERC7802.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title IRLCLiquidityUnifier
 * @dev Interface for the RLC Liquidity Unifier contract, extending the IERC7802 interface.
 *
 * This interface defines the contract for managing RLC (iExec's native token) liquidity
 * across different chains or protocols. It extends ERC-7802, which is likely a standard
 * for cross-chain token management.
 *
 * The RLC Liquidity Unifier appears to be designed to:
 * - Provide a unified interface for RLC token operations
 * - Handle liquidity management across different bridges
 * - Maintain compatibility with ERC-7802 standards
 */
interface IRLCLiquidityUnifier is IERC7802 {
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
