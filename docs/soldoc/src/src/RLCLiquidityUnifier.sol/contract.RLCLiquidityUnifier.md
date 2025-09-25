# RLCLiquidityUnifier
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/9831a5d81f09ff463f49d410c2aa12b7da3abdfa/src/RLCLiquidityUnifier.sol)

**Inherits:**
UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, [IRLCLiquidityUnifier](/src/interfaces/IRLCLiquidityUnifier.sol/interface.IRLCLiquidityUnifier.md), IERC7802

*This contract facilitates cross-chain liquidity unification by allowing
the minting and burning of tokens on the RLC token contract. All bridges
should interact with this contract to perform RLC transfers.
The implementation is inspired by the OpenZeppelin ERC20Bridgeable contract
without being an ERC20 token itself. Functions are overridden to lock/unlock
tokens on an external ERC20 contract. ERC20Bridgeable is not used directly
because it embarks the ERC20 token logic, which is not needed here.*


## State Variables
### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### TOKEN_BRIDGE_ROLE

```solidity
bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");
```


### RLC_TOKEN
**Note:**
oz-upgrades-unsafe-allow: state-variable-immutable


```solidity
IERC20Metadata public immutable RLC_TOKEN;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor(address rlcToken);
```

### initialize

Initializes the contract with the given parameters.


```solidity
function initialize(address initialAdmin, address initialUpgrader) public initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialAdmin`|`address`|address of the admin wallet|
|`initialUpgrader`|`address`|address of the upgrader wallet|


### crosschainMint

*See [IERC7802-crosschainMint](/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Bridgeable.sol/abstract.ERC20Bridgeable.md#crosschainmint).
Unlocks RLC tokens from this contract's balance and transfers them to the recipient.
This function is called when tokens are being received from another chain via the bridge.
Emits a {CrosschainMint} event indicating tokens were unlocked for cross-chain transfer.
Cross-chain flow:
1. Tokens are burned/locked on the source chain.
2. The bridge calls this function to unlock the equivalent tokens amount on the destination chain.
3. Tokens are transferred from this contract's balance to the recipient.
Requirements:
- Caller must have TOKEN_BRIDGE_ROLE (typically the LayerZero bridge contract)
- Contract must have sufficient RLC token balance to fulfill the transfer
- `to` address must be valid (non-zero)*

**Note:**
security: Only authorized bridge contracts can call this function


```solidity
function crosschainMint(address to, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to receive the unlocked RLC tokens|
|`value`|`uint256`|The amount of RLC tokens to unlock and transfer|


### crosschainBurn

*See [IERC7802-crosschainBurn](/lib/openzeppelin-contracts/contracts/token/ERC20/extensions/draft-ERC20Bridgeable.sol/abstract.ERC20Bridgeable.md#crosschainburn).
Locks RLC tokens by transferring them from the sender to this contract's reserve.
This function is called when tokens are being sent to another chain via the bridge.
Emits a {CrosschainBurn} event indicating tokens were locked for cross-chain transfer.
Cross-chain flow:
1. The user approves this contract to spend RLC tokens on their behalf.
2. The user initiates a cross-chain transfer through the bridge.
3. The bridge calls this function to lock tokens on the source chain.
4. Tokens are transferred from the sender's account to this contract (locked).
Requirements:
- Caller must have TOKEN_BRIDGE_ROLE (typically the LayerZero bridge contract)
- `from` address must have approved this contract to spend at least `value` tokens
- `from` address must have sufficient RLC token balance*

**Note:**
security: Only authorized bridge contracts can call this function


```solidity
function crosschainBurn(address from, uint256 value) external override onlyRole(TOKEN_BRIDGE_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to lock RLC tokens from (must have approved this contract)|
|`value`|`uint256`|The amount of RLC tokens to lock in this contract|


### decimals

Returns the number of decimal places used by the underlying RLC token

*This function provides LayerZero bridge compatibility by exposing the decimal
precision of the underlying RLC token. LayerZero's OFT (Omnichain Fungible Token)
standard requires this information to properly handle token amounts across different
chains with potentially different decimal representations.*

**Note:**
bridge-compatibility: Required by LayerZero OFT standard


```solidity
function decimals() external pure returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|The decimal places of the RLC token (typically 9 for RLC)|


### supportsInterface

*See [IERC165-supportsInterface](/src/RLCCrosschainToken.sol/contract.RLCCrosschainToken.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlDefaultAdminRulesUpgradeable, IERC165)
    returns (bool);
```

### _authorizeUpgrade

*Authorizes upgrades of the proxy. It can only be called by
an account with the UPGRADER_ROLE.*


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```

