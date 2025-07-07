# IexecLayerZeroBridge
[Git Source](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/e45e89d2b74018386866544b530e980898300784/src/bridges/layerZero/IexecLayerZeroBridge.sol)

**Inherits:**
UUPSUpgradeable, AccessControlDefaultAdminRulesUpgradeable, OFTCoreUpgradeable, [DualPausableUpgradeable](/src/bridges/utils/DualPausableUpgradeable.sol/abstract.DualPausableUpgradeable.md), [IIexecLayerZeroBridge](/src/interfaces/IIexecLayerZeroBridge.sol/interface.IIexecLayerZeroBridge.md)

*A LayerZero OFT (Omnichain Fungible Token) bridge implementation for RLC tokens
This contract enables cross-chain transfer of RLC tokens using LayerZero's OFT standard.
It overrides the `_debit` and `_credit` functions to use external mint and burn functions
on the CrosschainRLC token contract.
Cross-chain Transfer Mechanism:
1. When sending tokens FROM this chain: RLC tokens are permanently burned from the sender's balance
2. When receiving tokens TO this chain: New RLC tokens are minted to the recipient's balance
This ensures the total supply across all chains remains constant - tokens destroyed on one
chain are minted on another, maintaining a 1:1 peg across the entire ecosystem.
Dual-Pause Emergency System:
1. Complete pause: Blocks all bridge operations (inbound and outbound transfers)
2. Only outbout transfers pause: Blocks only outbound transfers, allows users to receive/withdraw funds
Architecture Overview:
This bridge supports two distinct deployment scenarios:
1. Non-Mainnet Chains (L2s, sidechains, etc.):
- BRIDGEABLE_TOKEN: Points to RLCCrosschain contract (mintable/burnable tokens)
- APPROVAL_REQUIRED: false (bridge can mint/burn directly)
- Mechanism: Mint tokens on transfer-in, burn tokens on transfer-out
2. Ethereum Mainnet:
- BRIDGEABLE_TOKEN: Points to LiquidityUnifier contract (manages original RLC tokens)
- APPROVAL_REQUIRED: true (requires user approval for token transfers)
- Mechanism: Lock tokens on transfer-out, unlock tokens on transfer-in
The LiquidityUnifier contract acts as a relayer, implementing ERC-7802 interface
to provide consistent lock/unlock operations for the original RLC token contract
that may not natively support the crosschain standard.*


## State Variables
### UPGRADER_ROLE
*Role identifier for accounts authorized to upgrade the contract*


```solidity
bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
```


### PAUSER_ROLE
*Role identifier for accounts authorized to pause/unpause the contract*


```solidity
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```


### BRIDGEABLE_TOKEN
**Note:**
oz-upgrades-unsafe-allow: state-variable-immutable


```solidity
address public immutable BRIDGEABLE_TOKEN;
```


### APPROVAL_REQUIRED
*Indicates the token transfer mechanism required for this deployment.
- true: Ethereum Mainnet deployment requiring user approval (lock/unlock mechanism)
- false: Non Ethereum Mainnet deployment with direct mint/burn capabilities
This flag indicates on which chain the bridge is deployed.*

**Note:**
oz-upgrades-unsafe-allow: state-variable-immutable


```solidity
bool private immutable APPROVAL_REQUIRED;
```


## Functions
### constructor

*Constructor for the LayerZero bridge contract*

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor(bool approvalRequired_, address bridgeableToken, address lzEndpoint)
    OFTCoreUpgradeable(IERC20Metadata(bridgeableToken).decimals(), lzEndpoint);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`approvalRequired_`|`bool`||
|`bridgeableToken`|`address`|The RLC token contract address that implements IERC7802 interface|
|`lzEndpoint`|`address`|The LayerZero endpoint address for this chain|


### initialize

Initializes the contract after proxy deployment


```solidity
function initialize(address initialAdmin, address initialUpgrader, address initialPauser) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`initialAdmin`|`address`|Address that will receive owner and default admin roles|
|`initialUpgrader`|`address`|Address that will receive the upgrader role|
|`initialPauser`|`address`|Address that will receive the pauser role|


### pause

LEVEL 1: Pauses all cross-chain transfers (complete shutdown)

*Can only be called by accounts with PAUSER_ROLE
When fully paused:
- All _debit operations (outbound transfers) are blocked
- All _credit operations (inbound transfers) are blocked
- Use this for critical security incidents (e.g., LayerZero exploit)*

**Note:**
security: Critical emergency function for complete bridge shutdown


```solidity
function pause() external onlyRole(PAUSER_ROLE);
```

### unpause

LEVEL 1: Unpauses all cross-chain transfers

*Can only be called by accounts with PAUSER_ROLE*


```solidity
function unpause() external onlyRole(PAUSER_ROLE);
```

### pauseOutboundTransfers

LEVEL 2: Pauses only outbound transfers.

*Can only be called by accounts with PAUSER_ROLE
When outbount transfers are paused:
- All _debit operations (outbound transfers) are blocked
- All _credit operations (inbound transfers) still work
- Users can still receive funds and "exit" their positions
- Use this for less critical issues or when you want to allow withdrawals*

**Note:**
security: Moderate emergency function allowing inbound messages
while blocking outbound transfers.


```solidity
function pauseOutboundTransfers() external onlyRole(PAUSER_ROLE);
```

### unpauseOutboundTransfers

LEVEL 2: Unpauses outbound transfers (restores send functionality)

*Can only be called by accounts with PAUSER_ROLE*


```solidity
function unpauseOutboundTransfers() external onlyRole(PAUSER_ROLE);
```

### approvalRequired

Indicates whether the OFT contract requires approval to send tokens
Approval is only required on the Ethereum Mainnet where the original RLC contract is deployed.


```solidity
function approvalRequired() external view virtual returns (bool);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|requiresApproval Returns true if deployed on Ethereum Mainnet, false otherwise|


### token

Returns the address of the underlying token being bridged


```solidity
function token() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the RLC token contract|


### owner

Returns the owner of the contract

*This override resolves the conflict between OwnableUpgradeable and
AccessControlDefaultAdminRulesUpgradeable, both of which define owner().
We use the OwnableUpgradeable version for consistency.*


```solidity
function owner()
    public
    view
    override(OwnableUpgradeable, AccessControlDefaultAdminRulesUpgradeable)
    returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|The address of the current owner|


### _debit

Burns tokens from the sender's balance as part of cross-chain transfer

*This function is called by LayerZero's OFT core when sending tokens
to another chain. It burns the specified amount from the sender's balance.
It overrides the `_debit` function
https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L56-L69
This function behavior is chain specific and works differently
depending on whether the bridge is deployed on Ethereum Mainnet or a non-mainnet chain.
IMPORTANT ASSUMPTIONS:
- This implementation assumes LOSSLESS transfers (1 token burned = 1 token minted)
- If BRIDGEABLE_TOKEN implements transfer fees, burn fees, or any other fee mechanism,
this function will NOT work correctly and would need to be modified
- The function would need pre/post balance checks to handle fee scenarios*

*This function is called for outbound transfers (when sending to another chain)
Pause Behavior:
- Blocked when contract is fully paused (Level 1 pause)
- Blocked when outbound transfers are paused (Level 2 pause)
- Uses both whenNotPaused and whenOutboundTransfersNotPaused modifiers*

**Note:**
security: Requires the RLC token to have granted burn permissions to this contract


```solidity
function _debit(address from, uint256 amountLD, uint256 minAmountLD, uint32 dstEid)
    internal
    override
    whenNotPaused
    whenOutboundTransfersNotPaused
    returns (uint256 amountSentLD, uint256 amountReceivedLD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`from`|`address`|The address to burn tokens from|
|`amountLD`|`uint256`|The amount of tokens to burn (in local decimals)|
|`minAmountLD`|`uint256`|The minimum amount to burn (for slippage protection)|
|`dstEid`|`uint32`|The destination chain endpoint ID|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountSentLD`|`uint256`|The amount of tokens burned on source chain|
|`amountReceivedLD`|`uint256`|The amount that will be minted on destination chain|


### _credit

Mints tokens to the specified account as part of cross-chain transfer.

*This function is called by LayerZero's OFT core when receiving tokens
from another chain. It mints the specified amount to the recipient's balance.
It overrides the `_credit` function
https://github.com/LayerZero-Labs/devtools/blob/a2e444f4c3a6cb7ae88166d785bd7cf2d9609c7f/packages/oft-evm/contracts/OFT.sol#L78-L88
This function behavior is chain agnostic and works the same for both chains that does or doesn't require approval.
IMPORTANT ASSUMPTIONS:
- This implementation assumes LOSSLESS transfers (1 token received = 1 token minted)
- If BRIDGEABLE_TOKEN implements minting fees or any other fee mechanism,
this function will NOT work correctly and would need to be modified
- The function would need pre/post balance checks to handle fee scenarios*

*This function is called for inbound transfers (when receiving from another chain)
Pause Behavior:
- Blocked ONLY when contract is fully paused (Level 1 pause)
- NOT blocked when outbound transfers are paused (Level 2) - users can still receive/exit
- Uses only whenNotPaused modifier*

**Notes:**
- security: Requires the RLC token to have granted mint permissions to this contract

- security: Uses 0xdead address if _to is zero address (minting to zero fails)


```solidity
function _credit(address to, uint256 amountLD, uint32)
    internal
    override
    whenNotPaused
    returns (uint256 amountReceivedLD);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to`|`address`|The address to mint tokens to|
|`amountLD`|`uint256`|The amount of tokens to mint (in local decimals)|
|`<none>`|`uint32`||

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amountReceivedLD`|`uint256`|The amount of tokens actually minted|


### _authorizeUpgrade

Authorizes contract upgrades

*This function is required by UUPS upgradeable pattern.
Only accounts with UPGRADER_ROLE can authorize upgrades.*

**Notes:**
- security: Critical function that controls contract upgrades

- security: Ensure proper testing and security review before any upgrade


```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newImplementation`|`address`|The address of the new implementation contract|


