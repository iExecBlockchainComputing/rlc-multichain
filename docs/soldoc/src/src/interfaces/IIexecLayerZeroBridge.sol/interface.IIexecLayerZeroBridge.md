# IIexecLayerZeroBridge
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/93b2d2b8fb41a03ccb6bc3a710204b628f122d69/src/interfaces/IIexecLayerZeroBridge.sol)


## Functions
### pause

Pauses the contract, disabling `_credit` & `_debit` functions.

*Should only be callable by authorized accounts: PAUSER_ROLE.*


```solidity
function pause() external;
```

### unpause

Unpauses the contract, re-enabling previously disabled functions (`_credit` & `_debit`).

*Should only be callable by authorized accounts: PAUSER_ROLE.*


```solidity
function unpause() external;
```

### pauseOutboundTransfers

Pauses only the `_debit` function, allowing `_credit` to still work.

*Should only be callable by authorized accounts: PAUSER_ROLE.*


```solidity
function pauseOutboundTransfers() external;
```

### unpauseOutboundTransfers

Unpauses the `_debit` function, allowing outbound transfers again.

*Should only be callable by authorized accounts: PAUSER_ROLE.*


```solidity
function unpauseOutboundTransfers() external;
```

## Errors
### OperationNotAllowed

```solidity
error OperationNotAllowed(string message);
```

