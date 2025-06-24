// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

/**
 * @dev See {RLCrosschainToken-approveAndCall}.
 * An interface for a contract that can receive approval from an ERC20 token and execute
 * a call with the provided calldata. It is used with `approveAndCall` functionality.
 * The original code can be found in the RLC token project:
 * https://github.com/iExecBlockchainComputing/rlc-token/blob/master/contracts/TokenSpender.sol
 *
 * @dev The ERC1363-onTransferReceived is not used because it is not compatible with the original
 * RLC token contract. See {RLCrosschainToken-approveAndCall} for more details.
 */
interface ITokenSpender {
    function receiveApproval(address from, uint256 value, address token, bytes memory data) external;
}
