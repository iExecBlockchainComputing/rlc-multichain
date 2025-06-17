// SPDX-FileCopyrightText: 2025 IEXEC BLOCKCHAIN TECH <contact@iex.ec>
// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.22;

interface ITokenSpender {
    function receiveApproval(address _from, uint256 _value, address _token, bytes memory _extraData) external;
}
