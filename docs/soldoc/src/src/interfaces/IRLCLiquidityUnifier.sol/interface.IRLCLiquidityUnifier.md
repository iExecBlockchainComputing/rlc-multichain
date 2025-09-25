# IRLCLiquidityUnifier
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/9831a5d81f09ff463f49d410c2aa12b7da3abdfa/src/interfaces/IRLCLiquidityUnifier.sol)

*Interface for the RLC Liquidity Unifier contract.
This interface defines the contract that is used to centralize the RLC liquidity
across different bridges.*


## Functions
### RLC_TOKEN

*Returns the address of the RLC token contract*


```solidity
function RLC_TOKEN() external view returns (IERC20Metadata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20Metadata`|The contract address of the RLC token|


### decimals

*Returns the number of decimal places used by the token*


```solidity
function decimals() external pure returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The number of decimal places (typically 9 for RLC)|


## Errors
### ERC7802InvalidToAddress
*Error indicating that the provided 'to' address is invalid for ERC-7802 operations.*


```solidity
error ERC7802InvalidToAddress(address addr);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The invalid address.|

### ERC7802InvalidFromAddress
*Error indicating that the provided 'from' address is invalid for ERC-7802 operations.*


```solidity
error ERC7802InvalidFromAddress(address addr);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr`|`address`|The invalid address.|

