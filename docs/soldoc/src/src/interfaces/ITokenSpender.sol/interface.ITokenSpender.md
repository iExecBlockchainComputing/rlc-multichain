# ITokenSpender
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/61326e3abe32aee8683989ab94220c30da0cb2e6/src/interfaces/ITokenSpender.sol)

*See [RLCrosschainToken-approveAndCall](/src/RLCCrosschainToken.sol/contract.RLCCrosschainToken.md#approveandcall).
An interface for a contract that can receive approval from an ERC20 token and execute
a call with the provided calldata. It is used with `approveAndCall` functionality.
The original code can be found in the RLC token project:
https://github.com/iExecBlockchainComputing/rlc-token/blob/master/contracts/TokenSpender.sol*

*The ERC1363-onTransferReceived is not used because it is not compatible with the original
RLC token contract and the PoCo. See [RLCrosschainToken-approveAndCall](/src/RLCCrosschainToken.sol/contract.RLCCrosschainToken.md#approveandcall) for more details.*


## Functions
### receiveApproval


```solidity
function receiveApproval(address from, uint256 value, address token, bytes memory data) external;
```

