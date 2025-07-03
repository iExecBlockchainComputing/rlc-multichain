# RLC Multichain Bridge

This project implements a cross-chain token bridge system for the RLC token using LayerZero's OFT (Omnichain Fungible Token) protocol. It enables seamless token transfers between multiple blockchains, initially supporting Ethereum Sepolia and Arbitrum Sepolia testnets.

## Architecture

The system consists of three main components that work together to enable cross-chain RLC transfers:

### Core Components

1. **RLCCrosschainToken**: An upgradeable ERC20 token that implements the [ERC-7802](https://eips.ethereum.org/EIPS/eip-7802) bridgeable token standard. This token can be minted and burned by authorized bridge contracts and is deployed on non-Ethereum chains.

2. **RLCLiquidityUnifier** (Ethereum Mainnet only): A liquidity management contract that locks/unlocks the original RLC tokens on Ethereum. It implements the ERC-7802 interface to work seamlessly with bridge contracts while managing liquidity from the existing RLC token contract.

3. **IexecLayerZeroBridge**: A LayerZero OFT bridge contract that handles cross-chain messaging and token transfers. This contract has **dual deployment modes** based on the chain:
   - **Ethereum Mode** (`APPROVAL_REQUIRED = true`): Interfaces with RLCLiquidityUnifier to lock/unlock original RLC tokens
   - **Non-Ethereum Mode** (`APPROVAL_REQUIRED = false`): Directly mints/burns RLCCrosschainToken

### Deployment Architecture

The bridge system uses a **dual-mode architecture** where the same `IexecLayerZeroBridge` contract behaves differently based on deployment configuration:

#### **Ethereum Mainnet Deployment**
- **Configuration**: `APPROVAL_REQUIRED = true`
- **BRIDGEABLE_TOKEN**: Points to `RLCLiquidityUnifier` contract
- **Mechanism**: Lock/unlock original RLC tokens
- **Components**:
  - Original RLC Token (existing ERC-20)
  - `RLCLiquidityUnifier` (ERC-7802 wrapper/adapter)
  - `IexecLayerZeroBridge` (LayerZero bridge in Ethereum mode)

#### **Non-Ethereum Chain Deployment (L2s, Sidechains)**
- **Configuration**: `APPROVAL_REQUIRED = false`
- **BRIDGEABLE_TOKEN**: Points to `RLCCrosschainToken` contract
- **Mechanism**: Mint/burn bridgeable tokens
- **Components**:
  - `RLCCrosschainToken` (ERC-7802 bridgeable token)
  - `IexecLayerZeroBridge` (LayerZero bridge in non-Ethereum mode)

### Key Features

- **ERC-7802 Compatibility**: All bridgeable tokens implement the [ERC-7802](https://eips.ethereum.org/EIPS/eip-7802) standard
- **Dual-Mode Bridge**: Single bridge contract with different behaviors for Ethereum vs. non-Ethereum chains
- **Upgradeable Contracts**: UUPS proxy pattern for safe upgrades across all components
- **Dual-Pause Emergency System**: Granular control over bridge operations with complete and send-only pause modes
- **Multi-Chain Support**: Designed to extend to any LayerZero-supported chain
- **Original Token Preservation**: Maintains the original RLC token on Ethereum through liquidity management
- **Approval Optimization**: Smart approval handling for UI compatibility (e.g., Stargate)

### Architecture Flow
[![Architecture Diagram](https://mermaid.ink/img/pako:eNqVVmtv4jgU_SuWR7Of0gykEELUrZTnTiWqmWVgP7RUI5MYsBrsrJ3MTlv639d2iBseU-0GgUxyjn3vOdfXeYEZyzH04ZqjcgNm8YICeYl62dxYwKTaYI7rLfiGS1YQtIANRF3TSXQvv2DGHjG9WvJP11fkOplGF07v6hO5fnhDTuYKOCF_1yQn1dOckhXBvEsZeT0HBDkqK3n_iHwX9u9v8E-cTdAT5neYs5CTfI1bfvD16_TLX8Hk-zT5c34zTeLfK17jk1m-J7PP92YKkNC8ZIRWewymeTM4kSDgSyInPCtBFM1UZhFnQmQbROiJFiqx04Sc_5nQChXiTEbBNPzPGX38CIyZFQMmq7Rg_zSIucBci6QGgFGDfwAXF9e7PgjKkrMfWEi-zFLspK-HTI1zQISKQgAhA9hp9xqQGmnAJZhxRMUKcwF-AwXLHk9nnMw1dAAm-jHjZE0oKlTN7dTP0ZRDaQ7NBfiSzsAWC4HWeLe3vEWa-Fyg7brQfh2gpZwGLccaPQIxLsgPFWsHGjomAEfDPHArlRcgM5VgUpI10oDlQGPHMgAs98Fb1lo_ZWarfOvOw5GDxjXpoHHzyME28sA-NuI46NAGYc2pOA3VQCL7F8qe0yq2fyntOSMS-7y2x_WStom8iavEPimWP2wwp8V79aK6lUJ-tjsleGCCidNIHrFtySimFeC4QBVhVGxIKToT2nLGBTTdDdwiKlPZSsoCHgbZIE2_u6Gy261QhjXOJK7rpIHGhOOs0kDZjtTie6jTjTIrkBAxXgHclsSKFIX_IXKjNB1ZouIyRf_DZTzshSMrYwXj_rJA2eMRHbXV1dDDfnKZpobuBJ6Teu_Qa1W8DTVNYyfoGWqael6v9w61eN4T46H6vIWsr3eIS9049-TES4eJZ8iDKEiHZ1btTKEMtKQzrXDdR8qGVpHu_bZOLLPbVOJdRFPj1n5nFM-Hz8K-pbdXEzq04BbzLSK5PIZfFHIBZTBbWRO-HOZ4heqiUmfOq4SiumLfnmgGfXXEWbAuc1ThmCBZHVvo62PCgiWid4xtW5D8C_0X-BP6jmtf9p3BeDwYjkd917XgE_T7nmuPveHYHYxHrjdynVcLPmt6z_ZGEjwee05P-dB3LMhZvd6YlVQbY_y2eYnQ7xKWfJdQuTRLc9k7MI9YTSu5es9pI040r0G9_gslqqfC)](https://mermaid.live/edit#pako:eNqVVmtv4jgU_SuWR7Of0gykEELUrZTnTiWqmWVgP7RUI5MYsBrsrJ3MTlv639d2iBseU-0GgUxyjn3vOdfXeYEZyzH04ZqjcgNm8YICeYl62dxYwKTaYI7rLfiGS1YQtIANRF3TSXQvv2DGHjG9WvJP11fkOplGF07v6hO5fnhDTuYKOCF_1yQn1dOckhXBvEsZeT0HBDkqK3n_iHwX9u9v8E-cTdAT5neYs5CTfI1bfvD16_TLX8Hk-zT5c34zTeLfK17jk1m-J7PP92YKkNC8ZIRWewymeTM4kSDgSyInPCtBFM1UZhFnQmQbROiJFiqx04Sc_5nQChXiTEbBNPzPGX38CIyZFQMmq7Rg_zSIucBci6QGgFGDfwAXF9e7PgjKkrMfWEi-zFLspK-HTI1zQISKQgAhA9hp9xqQGmnAJZhxRMUKcwF-AwXLHk9nnMw1dAAm-jHjZE0oKlTN7dTP0ZRDaQ7NBfiSzsAWC4HWeLe3vEWa-Fyg7brQfh2gpZwGLccaPQIxLsgPFWsHGjomAEfDPHArlRcgM5VgUpI10oDlQGPHMgAs98Fb1lo_ZWarfOvOw5GDxjXpoHHzyME28sA-NuI46NAGYc2pOA3VQCL7F8qe0yq2fyntOSMS-7y2x_WStom8iavEPimWP2wwp8V79aK6lUJ-tjsleGCCidNIHrFtySimFeC4QBVhVGxIwKToT2nLGBTTdDdwiKlPZSsoCHgbZIE2_u6Gy261QhjXOJK7rpIHGhOOs0kDZjtTie6jTjTIrkBAxXgHclsSKFIX_IXKjNB1ZouIyRf_DZTzshSMrYwXj_rJA2eMRHbXV1dDDfnKZpobuBJ6Teu_Qa1W8DTVNYyfoGWqael6v9w61eN4T46H6vIWsr3eIS9049-TES4eJZ8iDKEiHZ1btTKEMtKQzrXDdR8qGVpHu_bZOLLPbVOJdRFPj1n5nFM-Hz8K-pbdXEzq04BbzLSK5PIZfFHIBZTBbWRO-HOZ4heqiUmfOq4SiumLfnmgGfXXEWbAuc1ThmCBZHVvo62PCgiWid4xtW5D8C_0X-BP6jmtf9p3BeDwYjkd917XgE_T7nmuPveHYHYxHrjdynVcLPmt6z_ZGEjwee05P-dB3LMhZvd6YlVQbY_y2eYnQ7xKWfJdQuTRLc9k7MI9YTSu5es9pI040r0G9_gslqqfC)
### Token Standards & Bridge Architecture

The bridge system leverages modern token standards to enable secure cross-chain transfers:

- **ERC-7802 Bridgeable Token Standard**: A new standard that defines interfaces for tokens that can be minted and burned by authorized bridge contracts
- **LayerZero OFT V2**: Omnichain Fungible Token protocol for cross-chain messaging and token transfers
- **OpenZeppelin UUPS Proxy**: Upgradeable proxy pattern for contract evolution while maintaining state

### Supported Networks

Currently deployed on:
- **Ethereum Sepolia** (testnet)
- **Arbitrum Sepolia** (testnet)

The architecture is designed to support additional networks in the future with minimal changes.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html) for contract compilation and deployment
- Ethereum wallet with Sepolia ETH and Arbitrum Sepolia ETH for gas
- RLC tokens on Sepolia testnet for bridge testing
- [LCOV](https://wiki.documentfoundation.org/Development/Lcov) for coverage report generation (install via `brew install lcov` on macOS)

## Installation

1. Clone the repository

   ```bash
   git clone https://github.com/iExecBlockchainComputing/rlc-multichain.git
   cd rlc-multichain
   ```

2. Install dependencies

   ```bash
   forge install
   ```

3. Create a `.env` file

    ```sh
    cp .env.template .env # and edit .env content
    ```

**Note:** To run scripts, you must save a wallet in the Foundry keystore. Use the following command to import a wallet with a raw private key:

```bash
cast wallet import --private-key <RAW_PRIVATE_KEY> <ACCOUNT_NAME>
```

Alternatively, you can use a mnemonic by specifying the `--mnemonic-path` option. Remember the `<ACCOUNT_NAME>` you choose, and set it in your `.env` file under the `ACCOUNT` field.

## Contract Overview

The core contracts of the multichain bridge system:

- [RLCCrosschainToken.sol](src/RLCCrosschainToken.sol) - Bridgeable ERC20 token implementing ERC-7802 standard
- [RLCLiquidityUnifier.sol](src/RLCLiquidityUnifier.sol) - Liquidity management for original RLC tokens on Ethereum
- [IexecLayerZeroBridge.sol](src/bridges/layerZero/IexecLayerZeroBridge.sol) - LayerZero OFT bridge for cross-chain transfers

## 📊 Code Coverage Analysis

### Generating Coverage Reports

To generate and view the coverage report, run:

```bash
make generate-coverage
```

## Deployment

### Local deployment

1. Start a local Anvil fork of Sepolia:

   ```bash
   make fork-sepolia
   ```

2. Start a local fork of Arbitrum Sepolia:

   ```bash
   make fork-arbitrum-sepolia
   ```

3. Deploy all contracts:

   ```bash
   make deploy-on-anvil
   ```

### Live network deployment

   ```bash
   make deploy-on-testnets
   ```

## Upgrades

All core contracts (RLCCrosschainToken, RLCLiquidityUnifier, and IexecLayerZeroBridge) are implemented using the UUPS pattern, allowing for seamless contract upgrades while maintaining the same proxy address.

### Upgrade Architecture

- **UUPS Proxies**: Both contracts use OpenZeppelin's UUPS proxy pattern
- **Upgrade Authorization**: Only the contract owner can authorize upgrades
- **State Preservation**: Contract state is preserved across upgrades
- **Initialization**: New contract versions can include initialization logic for new features

### Upgrade Process

#### 1. Local Testing (Anvil)

Test upgrades locally before deploying to live networks:

```bash
# Test upgrade process on local forks
make upgrade-on-anvil
```

#### 2. Live Network Upgrades

Execute upgrades on testnets:

```bash
make upgrade-on-testnets
```

### Upgrade Safety Features

- **Storage Layout Protection**: Prevents storage slot conflicts between versions
- **Constructor Validation**: Ensures new implementations have compatible constructors
- **Manual Testing**: Always test upgrades thoroughly on testnets before deploying to mainnet

## Usage

### Bridge RLC

A. To send RLC tokens from Ethereum Sepolia to Arbitrum Sepolia:

```bash
make send-tokens-to-arbitrum-sepolia
```

This will:

1. Approve the RLCLiquidityUnifier to spend your RLC tokens
2. Initiate the cross-chain transfer through the IexecLayerZeroBridge
3. Lock original RLC tokens in the RLCLiquidityUnifier and mint equivalent RLCCrosschainToken on Arbitrum

B. To send RLC tokens from Arbitrum Sepolia back to Ethereum Sepolia:

```bash
make send-tokens-to-sepolia
```

This will:

1. Burn RLCCrosschainToken tokens on Arbitrum
2. Send a cross-chain message via LayerZero to Ethereum
3. Release the original RLC tokens from the RLCLiquidityUnifier on Ethereum

## How It Works

### Cross-Chain Transfer Mechanism

The bridge operates using different mechanisms depending on the source chain:

**Ethereum → Other Chains:**
1. User approves RLCLiquidityUnifier to spend original RLC tokens
2. RLCLiquidityUnifier locks the original RLC tokens  
3. IexecLayerZeroBridge sends a LayerZero message to the destination chain
4. Destination chain's IexecLayerZeroBridge receives the message and mints RLCCrosschainToken

**Other Chains → Ethereum:**
1. User initiates transfer from RLCCrosschainToken
2. Source chain's IexecLayerZeroBridge burns the RLCCrosschainToken
3. LayerZero delivers a message to Ethereum's IexecLayerZeroBridge
4. Ethereum's RLCLiquidityUnifier releases the original RLC tokens to the recipient

**Chain-to-Chain (Non-Ethereum):**
1. Source chain burns RLCCrosschainToken
2. LayerZero message triggers minting of RLCCrosschainToken on destination chain

This design ensures the total supply across all chains remains constant while preserving the original RLC token on Ethereum.


## Security Considerations

- The bridge security relies on LayerZero's security model
- Administrative functions are protected by the Ownable pattern
- UUPS upgrade authorization is restricted to contract owners only
- Use caution when setting trusted remotes to prevent unauthorized cross-chain interactions
- Always test upgrades thoroughly on testnets before deploying to mainnet
- Upgrade safety is enforced through OpenZeppelin's upgrade validation

## Access Control: Role-Based Security

The RLC multichain bridge system implements a comprehensive **role-based access control system** using OpenZeppelin's `AccessControlDefaultAdminRulesUpgradeable`. This ensures that critical operations are restricted to authorized accounts only.

### 🔐 System Roles

#### **DEFAULT_ADMIN_ROLE**
**Purpose**: Supreme administrator with ultimate control over all contracts
- **Scope**: All contracts (inherited from OpenZeppelin)
- **Permissions**:
  - Grant and revoke any role to any address
  - Manage role administrators
  - Ultimate fallback authority for contract governance
- **Security**: 🔴 **CRITICAL** - This role has unlimited power
- **Best Practice**: Use a multisig wallet or governance contract

#### **UPGRADER_ROLE**
**Purpose**: Authorized to upgrade contract implementations
- **Scope**: All contracts (`IexecLayerZeroBridge`, `RLCLiquidityUnifier`, `RLCCrosschainToken`)
- **Permissions**:
  - `_authorizeUpgrade()` - Approve new implementation contracts
  - Deploy new versions via UUPS proxy pattern
- **Security**: 🔴 **CRITICAL** - Can change contract logic
- **Best Practice**: Use a separate secure wallet, test all upgrades on testnets first

#### **PAUSER_ROLE**
**Purpose**: Emergency response for bridge operations
- **Scope**: `IexecLayerZeroBridge` only
- **Permissions**:
  - `pause()` - Complete bridge shutdown (Level 1 emergency)
  - `unpause()` - Resume all bridge operations
  - `pauseSend()` - Block outgoing transfers only (Level 2 emergency)
  - `unpauseSend()` - Resume outgoing transfers
- **Security**: 🟡 **HIGH** - Can halt bridge operations
- **Best Practice**: Use a monitoring system or incident response team wallet

#### **TOKEN_BRIDGE_ROLE**
**Purpose**: Authorized bridge contracts for cross-chain operations
- **Scope**: `RLCLiquidityUnifier` and `RLCCrosschainToken`
- **Permissions**:
  - `crosschainMint()` - Mint tokens on destination chain
  - `crosschainBurn()` - Burn tokens on source chain
  - ERC-7802 standard compliance operations
- **Security**: 🟡 **HIGH** - Can mint/burn tokens
- **Best Practice**: Only grant to audited and trusted bridge contracts

### 🛡️ Role Assignment Strategy

#### **Initial Setup**
```solidity
// Typically assigned during contract initialization
DEFAULT_ADMIN_ROLE → Multisig/Governance Contract
UPGRADER_ROLE      → Secure Upgrade Wallet  
PAUSER_ROLE        → Monitoring/Emergency Response
TOKEN_BRIDGE_ROLE  → IexecLayerZeroBridge Contract
```

#### **Role Relationships**
- **DEFAULT_ADMIN_ROLE** can grant/revoke all other roles
- **UPGRADER_ROLE** is independent - cannot grant roles to others
- **PAUSER_ROLE** is independent - focused solely on emergency controls
- **TOKEN_BRIDGE_ROLE** is functional - enables cross-chain operations

### 🔒 Security Best Practices

#### **Multi-Signature Requirements**
- **DEFAULT_ADMIN_ROLE**: Use 3-of-5 or 4-of-7 multisig
- **UPGRADER_ROLE**: Use 2-of-3 multisig minimum
- **PAUSER_ROLE**: Can use 1-of-3 for emergency response speed

#### **Role Separation**
- Never assign multiple critical roles to the same address
- Use different secure wallets for different roles
- Consider time-locked upgrades for additional security

#### **Monitoring & Alerting**
- Monitor all role-restricted function calls
- Set up alerts for unexpected role assignments
- Regular audits of role holders

#### **Emergency Procedures**
- **PAUSER_ROLE** should have 24/7 monitoring capabilities
- **DEFAULT_ADMIN_ROLE** can revoke compromised accounts
- Test emergency procedures regularly on testnets

### 🔍 Role Verification

To verify current role assignments:

```bash
# Check if address has DEFAULT_ADMIN_ROLE
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)" "0x0000000000000000000000000000000000000000000000000000000000000000" $ADDRESS

# Check if address has UPGRADER_ROLE  
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)" "0x189ab7a9244df0848122154315af71fe140f3db0fe014031783b0946b8c9d2e3" $ADDRESS

# Check if address has PAUSER_ROLE
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)" "0x65d7a28e3265b37a6474929f336521b332c1681b933f6cb9f3376673440d862a" $ADDRESS

# Check if address has TOKEN_BRIDGE_ROLE
cast call $CONTRACT_ADDRESS "hasRole(bytes32,address)" "0xd7c4527c99f13bf6a80d3bc15ebce76f7f8256ab4fbf63363b10858db314c978" $ADDRESS
```

## Emergency Controls: Dual-Pause System

The IexecLayerZeroBridge implements a sophisticated **dual-pause emergency system** designed to handle different types of security incidents while minimizing user impact.

### 🚨 Pause Levels

#### Level 1: Complete Pause (`pause()`)
**Use Case**: Critical security incidents requiring immediate complete shutdown
- **Blocks**: ❌ All bridge operations (incoming and outgoing transfers)
- **Allows**: ✅ Admin functions, view functions
- **Emergency**: Maximum protection - complete bridge shutdown

#### Level 2: Send Pause (`pauseSend()`)
**Use Case**: Destination chain issues, or controlled maintenance
- **Blocks**: ❌ Outgoing transfers only (users can't initiate send requests)
- **Allows**: ✅ Incoming transfers (users can still receive tokens from other chains)
- **Benefit**: Allows completion of in-flight transfers while preventing new ones

## Contract Verification

### Automatic Verification

Contracts are automatically verified on block explorers during deployment when using testnets:

```bash
# Deploys and verifies contracts on testnets
make deploy-on-testnets

# Upgrades and verifies contracts on testnets  
make upgrade-on-testnets
```

The verification is handled by Foundry's built-in `--verify` flag, which submits the source code and constructor arguments to the respective block explorers (Etherscan, Arbiscan, etc.).

## Gas Costs and Fees

LayerZero transactions require fees to cover:

1. Gas on the source chain
2. Gas on the destination chain (prepaid)
3. LayerZero relayer fees

The scripts automatically calculate these fees and include them in the transaction.

## Troubleshooting

## References

- [ERC-7802: Crosschain Token Interface](https://eips.ethereum.org/EIPS/eip-7802) - The crosschain token standard used by bridgeable tokens
- [LayerZero Documentation](https://layerzero.gitbook.io/docs/)
- [LayerZero OFT V2 Protocol](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)
- [OpenZeppelin UUPS Proxy Pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
- [OpenZeppelin Upgrade Safety](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Forge Coverage](https://book.getfoundry.sh/reference/forge/forge-coverage)
- [iExec Platform Documentation](https://docs.iex.ec/)

## TODO

- Use an entreprise RPC URL for `secrets.SEPOLIA_RPC_URL` in Github environment `ci`.
- Add git pre-commit hook to format code locally.
