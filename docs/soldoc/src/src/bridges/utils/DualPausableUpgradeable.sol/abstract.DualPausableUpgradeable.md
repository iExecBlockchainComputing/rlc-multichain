# DualPausableUpgradeable
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/93b2d2b8fb41a03ccb6bc3a710204b628f122d69/src/bridges/utils/DualPausableUpgradeable.sol)

**Inherits:**
PausableUpgradeable

*Abstract contract providing independent pause controls for different operation types.
Implements two independent pause mechanisms:
1. Complete pause (inherited from PausableUpgradeable): Blocks ALL operations
2. Outbound transfer pause (new functionality): Blocks only "send" operations while allowing "receive"
Emergency Response Scenarios:
- Complete pause: Critical security incidents requiring full shutdown
- Outbound transfer only pause: Allows inbound requests of already ongoing transfers to complete while
preventing new outbound transfers.*

**Note:**
storage-location: erc7201:iexec.storage.DualPausable


## State Variables
### DUAL_PAUSABLE_STORAGE_LOCATION
keccak256(abi.encode(uint256(keccak256("iexec.storage.DualPausable")) - 1)) & ~bytes32(uint256(0xff))


```solidity
bytes32 private constant DUAL_PAUSABLE_STORAGE_LOCATION =
    0xcfbc5ec03206ba5826cf1103520b82c735e9bad14c6d8ed92dff9144ead3f400;
```


## Functions
### _getDualPausableStorage


```solidity
function _getDualPausableStorage() private pure returns (DualPausableStorage storage $);
```

### whenOutboundTransfersNotPaused

Use this modifier for functions that should be blocked during outbound transfer pause

*Modifier for send operations - blocks when outbound transfer is paused*


```solidity
modifier whenOutboundTransfersNotPaused();
```

### whenOutboundTransfersPaused

Use this modifier for administrative functions that should only work during outbound transfer pause

*Modifier to make a function callable only when send operations are paused*


```solidity
modifier whenOutboundTransfersPaused();
```

### __DualPausable_init


```solidity
function __DualPausable_init() internal onlyInitializing;
```

### __DualPausable_init_unchained


```solidity
function __DualPausable_init_unchained() internal onlyInitializing;
```

### outboundTransfersPaused

*Returns true if send operations are paused, false otherwise*


```solidity
function outboundTransfersPaused() public view virtual returns (bool);
```

### pauseStatus

*Returns the overall operational state of the contract*


```solidity
function pauseStatus() public view virtual returns (bool fullyPaused, bool onlyOutboundTransfersPaused);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fullyPaused`|`bool`|True if complete pause is active (blocks all operations)|
|`onlyOutboundTransfersPaused`|`bool`|True if outbound transfer pause is active (blocks only send operations)|


### _requireOutboundTransfersNotPaused

*Throws if send operations are paused*


```solidity
function _requireOutboundTransfersNotPaused() internal view virtual;
```

### _requireOutboundTransfersPaused

*Throws if send operations are not paused*


```solidity
function _requireOutboundTransfersPaused() internal view virtual;
```

### _pauseOutboundTransfers

*Triggers outbound transfers pause.
Requirements:
- Send operations must not already be paused*


```solidity
function _pauseOutboundTransfers() internal virtual whenOutboundTransfersNotPaused;
```

### _unpauseOutboundTransfers

*Unpauses outbound transfers.
Requirements:
- Send operations must already be paused*


```solidity
function _unpauseOutboundTransfers() internal virtual whenOutboundTransfersPaused;
```

## Events
### OutboundTransfersPaused
*Emitted when outbound transfer pause is triggered by `account`*


```solidity
event OutboundTransfersPaused(address account);
```

### OutboundTransfersUnpaused
*Emitted when outbound transfer pause is lifted by `account`*


```solidity
event OutboundTransfersUnpaused(address account);
```

## Errors
### EnforcedOutboundTransfersPause
*The operation failed because send operations are paused*


```solidity
error EnforcedOutboundTransfersPause();
```

### ExpectedOutboundTransfersPause
*The operation failed because send operations are not paused*


```solidity
error ExpectedOutboundTransfersPause();
```

## Structs
### DualPausableStorage
**Note:**
storage-location: erc7201:iexec.storage.DualPausable


```solidity
struct DualPausableStorage {
    bool _outboundTransfersPaused;
}
```

