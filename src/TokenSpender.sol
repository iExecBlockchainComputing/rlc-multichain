pragma solidity ^0.8.22;
// SPDX-License-Identifier: UNLICENSED

abstract contract TokenSpender {
    function receiveApproval(address _from, uint256 _value, address _token, bytes memory _extraData) public virtual;
}