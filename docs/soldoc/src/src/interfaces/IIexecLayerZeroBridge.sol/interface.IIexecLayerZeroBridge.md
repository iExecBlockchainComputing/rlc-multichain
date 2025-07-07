# IIexecLayerZeroBridge
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/e45e89d2b74018386866544b530e980898300784/src/interfaces/IIexecLayerZeroBridge.sol)


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

