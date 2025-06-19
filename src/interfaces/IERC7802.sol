// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.22;

// Code copied from OpenZeppelin's community contract `IERC7802`
// https://github.com/OpenZeppelin/openzeppelin-community-contracts/blob/075587479556632d3dd9e9e3b37417cabf3e26a3/contracts/interfaces/IERC7802.sol

/**
 * @notice Defines the interface for crosschain ERC20 transfers.
 */
interface IERC7802 {
    /**
     * @notice Emitted when a crosschain transfer mints tokens.
     * @param to       Address of the account tokens are being minted for.
     * @param amount   Amount of tokens minted.
     * @param sender   Address of the caller (msg.sender) who invoked crosschainMint.
     */
    event CrosschainMint(address indexed to, uint256 amount, address indexed sender);

    /**
     * @notice Emitted when a crosschain transfer burns tokens.
     * @param from     Address of the account tokens are being burned from.
     * @param amount   Amount of tokens burned.
     * @param sender   Address of the caller (msg.sender) who invoked crosschainBurn.
     */
    event CrosschainBurn(address indexed from, uint256 amount, address indexed sender);

    /**
     * @notice Mint tokens through a crosschain transfer.
     * @param to     Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function crosschainMint(address to, uint256 amount) external;

    /**
     * @notice Burn tokens through a crosschain transfer.
     * @param from   Address to burn tokens from.
     * @param amount Amount of tokens to burn.
     */
    function crosschainBurn(address from, uint256 amount) external;
}
