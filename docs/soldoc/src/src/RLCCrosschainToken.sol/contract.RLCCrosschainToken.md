# RLCCrosschainToken
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/93b2d2b8fb41a03ccb6bc3a710204b628f122d69/src/RLCCrosschainToken.sol)

**Inherits:**
UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, ERC20PermitUpgradeable, ERC20BridgeableUpgradeable

This contract is an upgradeable (UUPS) ERC20 token with cross-chain capabilities.
It implements the ERC-7802 (https://eips.ethereum.org/EIPS/eip-7802) standard for
cross-chain token transfers. It allows minting and burning of tokens as requested
by permitted bridge contracts.
To whitelist a token bridge contract, the admin (with `DEFAULT_ADMIN_ROLE`) sends
a transaction to grant the role `TOKEN_BRIDGE_ROLE` to the bridge contract address
using `grantRole` function.


## State Variables
### UPGRADER_ROLE

```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### TOKEN_BRIDGE_ROLE

```solidity
bytes32 public constant TOKEN_BRIDGE_ROLE = keccak256("TOKEN_BRIDGE_ROLE");
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the contract with the given parameters.


```solidity
function initialize(string memory name, string memory symbol, address initialAdmin, address initialUpgrader)
    public
    initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`name`|`string`|name of the token|
|`symbol`|`string`|symbol of the token|
|`initialAdmin`|`address`|address of the admin wallet|
|`initialUpgrader`|`address`|address of the upgrader wallet|


### approveAndCall

Approves the spender to spend the specified amount of tokens and calls the `receiveApproval`
function on the spender contract. Original code can be found in the RLC token project:
https://github.com/iExecBlockchainComputing/rlc-token/blob/master/contracts/RLC.sol#L84-L89

*The ERC1363 is not used because it is not compatible with the original RLC token contract:
- The RLC uses `receiveApproval` while the ERC1363 uses `onTransferReceived`.
- The PoCo exposes `receiveApproval` in its interface.
- Openzeppelin's implementation of ERC1363 uses Solidity custom errors.
This could be changed in the future, but for now, we keep the original interface to insure
compatibility with existing Dapps and SDKs.*


```solidity
function approveAndCall(address spender, uint256 value, bytes calldata data) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`spender`|`address`|address of the spender|
|`value`|`uint256`|amount of tokens to approve|
|`data`|`bytes`|additional data to pass to the spender|


### supportsInterface

*See [IERC165-supportsInterface](/lib/forge-std/src/interfaces/IERC165.sol/interface.IERC165.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override(AccessControlDefaultAdminRulesUpgradeable, ERC20BridgeableUpgradeable)
    returns (bool);
```

### decimals

Uses the same decimals number as the original RLC token.


```solidity
function decimals() public pure override returns (uint8);
```

### _authorizeUpgrade

*Authorizes upgrades of the proxy. It can only be called by
an account with the UPGRADER_ROLE.*


```solidity
function _authorizeUpgrade(address) internal override onlyRole(UPGRADER_ROLE);
```

### _checkTokenBridge

Checks if the caller is a trusted token bridge that is allowed by iExec to call
`crosschainMint` or `crosschainBurn` functions.

*This function is called by the modifier `onlyTokenBridge` in the
`ERC20BridgeableUpgradeable` contract.*


```solidity
function _checkTokenBridge(address) internal view override onlyRole(TOKEN_BRIDGE_ROLE);
```

