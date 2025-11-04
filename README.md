# RLC Multichain Bridge

This project implements a cross-chain token bridge system for the RLC token using LayerZero's OFT (Omnichain Fungible Token) protocol. It enables seamless token transfers between multiple blockchains, initially supporting Ethereum and Arbitrum mainnets.

## Diagrams and source code docs (soldocs):

  - [Diagrams](docs/diagrams)
  - [Source code docs](docs/soldoc/src/SUMMARY.md)

## Audits

* [Halborn audit report](audits/Halborn_iExec-RLC-Multichain-Bridge-Smart-Contract-Security-Assessment-Report.pdf)

## Architecture

The system consists of three main components that work together to enable cross-chain RLC transfers:

### Core Components

1. **RLCLiquidityUnifier** (Ethereum Mainnet only): A liquidity management contract that acts as an intermediary between the original RLC token and supported bridges. It enables the locking and unlocking of RLC tokens on Ethereum, and implements the ERC-7802 interface to ensure seamless integration with various bridge contracts, while centralizing liquidity on their behalf.

2. **IexecLayerZeroBridge**: A LayerZero OFT bridge contract that handles cross-chain messaging and token transfers. This contract has **dual deployment modes** based on the chain:
   - **Ethereum Mainnet Mode** (`APPROVAL_REQUIRED = true`): Interfaces with RLCLiquidityUnifier to lock/unlock original RLC tokens
   - **Non-Ethereum Mode** (`APPROVAL_REQUIRED = false`): Directly mints/burns RLCCrosschainToken

3. **RLCCrosschainToken**: An upgradeable ERC20 token that implements the [ERC-7802](https://eips.ethereum.org/EIPS/eip-7802) bridgeable token standard. This token can be minted and burned by authorized bridge contracts and is deployed on Non-Mainnet chains.

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

- **ERC-7802 Compatibility**:  Implement the [ERC-7802](https://eips.ethereum.org/EIPS/eip-7802) standard as a future-proof architecture for bridge compatibility
- **Dual-Mode Bridge**: Single bridge contract with different behaviors for Ethereum Mainnet vs. non-Mainnet chains
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
- **Ethereum Mainnet**
- **Arbitrum One**

The architecture is designed to support additional networks in the future with minimal changes.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html) for contract compilation and deployment
- Ethereum wallet with ETH and Arbitrum ETH for gas
- RLC tokens for bridge testing
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
- [RLCLiquidityUnifier.sol](src/RLCLiquidityUnifier.sol) - Liquidity management for original RLC tokens on Ethereum (implements ERC-7802 standard as well).
- [IexecLayerZeroBridge.sol](src/bridges/layerZero/IexecLayerZeroBridge.sol) - LayerZero OFT bridge for cross-chain transfers

## Usage

### Network Support

The bridge currently supports:

#### **Testnets**
- **Ethereum Sepolia** ↔ **Arbitrum Sepolia**

#### **Mainnets**
- **Ethereum Mainnet** ↔ **Arbitrum Mainnet**

### Bridge RLC on Testnets

A. To send RLC tokens from Ethereum Sepolia to Arbitrum Sepolia:

```bash
make send-tokens-to-arbitrum-sepolia
```

This will:

1. Approve IexecLayerZeroBridge to spend your original RLC tokens
2. IexecLayerZeroBridge transfers RLC tokens directly to RLCLiquidityUnifier (bypassing crosschainBurn for UI compatibility)
3. RLCLiquidityUnifier receives and locks the original RLC tokens
4. IexecLayerZeroBridge sends a LayerZero message to the destination chain
5. Destination chain's IexecLayerZeroBridge receives the message and mints RLCCrosschainToken

B. To send RLC tokens from Arbitrum Sepolia back to Ethereum Sepolia:

```bash
make send-tokens-to-ethereum-sepolia
```

This will:

1. Burn RLCCrosschainToken tokens on Arbitrum
2. Send a cross-chain message via LayerZero to Ethereum
3. Release the original RLC tokens from the RLCLiquidityUnifier on Ethereum

### Bridge RLC on Mainnets

A. To send RLC tokens from Ethereum Mainnet to Arbitrum Mainnet:

```bash
make send-tokens-to-arbitrum-mainnet
```

B. To send RLC tokens from Arbitrum Mainnet back to Ethereum Mainnet:

```bash
make send-tokens-to-ethereum-mainnet
```

## 📊 Code Coverage Analysis

### Generating Coverage Reports

To generate and view the coverage report, run:

```bash
make generate-coverage
```

## Deployment

### Local deployment

1. Start a local Anvil fork of Ethereum:

   ```bash
   make fork-ethereum
   ```

2. Start a local fork of Arbitrum:

   ```bash
   make fork-arbitrum
   ```

3. Deploy all contracts:

   ```bash
   make deploy-on-anvil
   ```

### Live network deployment
   ```bash
  # deploy-on-testnets is also available.
   make deploy-on-mainnets
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
make upgrade-bridge-on-anvil
```

#### 2. Live Network Upgrades

Execute upgrades on live networks:

```bash
make upgrade-bridge-on-mainnets
```

### Upgrade Safety Features

- **Storage Layout Protection**: Prevents storage slot conflicts between versions
- **Constructor Validation**: Ensures new implementations have compatible constructors
- **Manual Testing**: Always test upgrades thoroughly on staging environments before deploying to mainnet


## How It Works

### Cross-Chain Transfer Mechanism

The bridge operates using different mechanisms depending on the source chain:

**Ethereum → Other Chains:**
1. User approves IexecLayerZeroBridge to spend original RLC tokens
2. IexecLayerZeroBridge transfers RLC tokens directly to RLCLiquidityUnifier (bypassing crosschainBurn for UI compatibility)
3. RLCLiquidityUnifier receives and locks the original RLC tokens
4. IexecLayerZeroBridge sends a LayerZero message to the destination chain
5. Destination chain's IexecLayerZeroBridge receives the message and mints RLCCrosschainToken

**Other Chains → Ethereum:**
1. User initiates transfer from RLCCrosschainToken
2. Source chain's IexecLayerZeroBridge burns the RLCCrosschainToken
3. LayerZero delivers a message to Ethereum's IexecLayerZeroBridge
4. Ethereum's RLCLiquidityUnifier releases the original RLC tokens to the recipient

**Chain-to-Chain (Non-Ethereum):**
1. Source chain burns RLCCrosschainToken
2. LayerZero message triggers minting of RLCCrosschainToken on destination chain

This design ensures the total supply across all chains remains constant while preserving the original RLC token on Ethereum.

## Access Control: Role-Based Security

The bridge system uses OpenZeppelin's role-based access control with the following roles:

- **DEFAULT_ADMIN_ROLE**: Supreme administrator with ultimate control over all contracts and role management
- **UPGRADER_ROLE**: Authorized to upgrade contract implementations via UUPS proxy pattern
- **PAUSER_ROLE**: Emergency response role that can pause/unpause bridge operations
- **TOKEN_BRIDGE_ROLE**: Authorized bridge contracts that can mint/burn tokens for cross-chain operations

## Emergency Controls: Dual-Pause System

The IexecLayerZeroBridge implements a sophisticated **dual-pause emergency system** designed to handle different types of security incidents while minimizing user impact.

### 🚨 Pause Levels

#### Level 1: Complete pause (`pause()`)
**Use Case**: Critical security incidents requiring immediate complete shutdown
- **Blocks**: ❌ All bridge operations (inbound and outbound transfers)
- **Allows**: ✅ Admin functions, view functions
- **Emergency**: Maximum protection - complete bridge shutdown

#### Level 2: Outbound transfers onlypPause (`pauseOutboundTransfers()`)
**Use Case**: Destination chain issues, or controlled maintenance
- **Blocks**: ❌ Outbound transfers only (users can't initiate send requests)
- **Allows**: ✅ Inbound transfers (users can still receive tokens when the request is initiated before the pause)
- **Benefit**: Allows completion of already triggered transfers while preventing new ones

## Contract Verification

### Automatic Verification

Contracts are automatically verified on block explorers during deployment:

```bash
# Deploys and verifies contracts on mainnet
make deploy-on-mainnets

# Upgrades and verifies contracts on mainnet
make upgrade-bridge-on-mainnets
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
- [LayerZero OFT V2 Protocol](https://docs.layerzero.network/v2/developers/evm/oft/quickstart)
- [OpenZeppelin UUPS Proxy Pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
- [OpenZeppelin Upgrade Safety](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Forge Coverage](https://book.getfoundry.sh/reference/forge/forge-coverage)
- [iExec Platform Documentation](https://docs.iex.ec/)

## How to release:

> **Note**:<br>
> Always deploy and validate on the Testnet first!

* Go to "Actions" section on GitHub.
* Trigger the `Deploy contracts` job then choose the correct deployment branch and the target GitHub environment.

Note that production GitHub environments `arbitrum` and `ethereum` can only be used with the `main` branch.

## Safe Multisig Integration

All critical administrative operations are secured using Safe (Gnosis Safe) multisig wallets. This ensures that important actions like contract upgrades, role management, and pause operations require approval from multiple authorized signers.

### Supported Operations

- **Pause/Unpause**: Control bridge operations with different pause levels

### GitHub Actions Workflows

- `.github/workflows/bridge-pause-safe.yml` - Propose pause/unpause transactions

All workflows use the reusable Safe multisig workflow from [iExecBlockchainComputing/github-actions-workflows](https://github.com/iExecBlockchainComputing/github-actions-workflows).

## TODO

- Use an enterprise RPC URL for `secrets.SEPOLIA_RPC_URL` in Github environment `ci`.
- Add git pre-commit hook to format code locally.
- Testing Documentation
- Parametrize the following addresses by chain in `config.json`:
```
  "initialAdmin": "0x111165a109feca14e4ad4d805f6460c7d206ead1",
  "initialUpgrader": "0x111121e2ec2557f484f65d5b1ad2b6b07b8acd23",
  "initialPauser": "0x11113fe3513787f5a4f5f19690700e2736b3056e",
```
- Clean README.md
