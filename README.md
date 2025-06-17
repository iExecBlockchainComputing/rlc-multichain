# RLC Layer Zero Bridge

This project implements a cross-chain token bridge for the RLC token between Ethereum and Arbitrum using LayerZero's OFT (Omnichain Fungible Token) protocol. It enables seamless token transfers between Ethereum Sepolia and Arbitrum Sepolia testnets.

## Architecture

The system consists of two main components:

1. **RLCAdapter (on Ethereum Sepolia)**: Wraps the existing RLC ERC-20 token to make it compatible with LayerZero's cross-chain messaging.
2. **RLCOFT (on Arbitrum Sepolia)**: A new token that's minted when RLC tokens are locked in the adapter on Ethereum, and burned when tokens are sent back.

[![Architecture Diagram](https://mermaid.ink/img/pako:eNqNVNtO4zAQ_RXLvAY2F3JpQEhpLrsPRUhQXqBoZRKXRjh2ZCdouf372nHSEhrYddV2MjnHZ-ZM4leYswLDED5wVG_AMllRIJdo73ViBdNmgzluK3CFa0ZKtIIaotblIr6VX7Bkj5ju0qflWXoZ2-bpj_LsbpeOClQ3mCtGH44oF9myT3_iLW5-p8tftwv0jPkN5gyktKhZSZseg2mhg73aI35fNny6dimnKpF_E-XL7H4R0eX8v4u4Fph3VasAMAoGG-_A4eHZmwWiuubsCQvQKHHxBkaWDPQObIMYESKAkBqfcP1FB3PAguWPuw1lc_ugY2kFLQSosBDoAb_15mqgjjucC2LOhDjMN6ikI7R0YYuWcYf2QIJJ-YT5h42lhRqnHFYgH5xLu3b1dT0qTweLhmnd7Rk56EQjJ_YU5mDecrpT2APEE91P9ZN82f2UV-lE919OKQPXlPx7Tj_BkiMq1mrTkWHbAvRvTpAQCV4DPLym65KQ8CD24izzDdFwSQ4PnMQ1576RM8J4eE9Q_njyiY-GV0Xz51bqZNmWb0eBnQXf8Vs1RM3NssSOzC03y4LANL_jkpeembjqs6u6WxPMD3xlnzE4N5jwUaAb_tDd6Mbgp7F9xlQTI4iestE_GuTlBBqwwrxCZSHPzFcFXUEpWuEVDGVY4DVqSaPOmXcJRW3Drp5pDkMpjg3Y1gVqcFIieUBVMFwjImS2RvSGsWoAyUsYvsI_MAysI8_yfNuZeY7tuUFgwGcYWjP3yLdN1_Jl5PiBab8b8KXbwDyaufbMOnYs27OsIPA8A3LWPmy2WrgoG8bP9ZnfHf2GPPpVN1qcy_cD85i1tJFKlj3UnHY8jXr_C5RA8AI)](https://mermaid.live/edit#pako:eNqNVNtO4zAQ_RXLvAY2F3JpQEhpLrsPRUhQXqBoZRKXRjh2ZCdouf372nHSEhrYddV2MjnHZ-ZM4leYswLDED5wVG_AMllRIJdo73ViBdNmgzluK3CFa0ZKtIIaotblIr6VX7Bkj5ju0qflWXoZ2-bpj_LsbpeOClQ3mCtGH44oF9myT3_iLW5-p8tftwv0jPkN5gyktKhZSZseg2mhg73aI35fNny6dimnKpF_E-XL7H4R0eX8v4u4Fph3VasAMAoGG-_A4eHZmwWiuubsCQvQKHHxBkaWDPQObIMYESKAkBqfcP1FB3PAguWPuw1lc_ugY2kFLQSosBDoAb_15mqgjjucC2LOhDjMN6ikI7R0YYuWcYf2QIJJ-YT5h42lhRqnHFYgH5xLu3b1dT0qTweLhmnd7Rk56EQjJ_YU5mDecrpT2APEE91P9ZN82f2UV-lE919OKQPXlPx7Tj_BkiMq1mrTkWHbAvRvTpAQCV4DPLym65KQ8CD24iyyDdFwSQ4PnMQ1576RM8J4eE9Q_njyiY-GV0Xz51bqZNmWb0eBnQXf8Vs1RM3NssSOzC03y4LANL_jkpeembjqs6u6WxPMD3xlnzE4N5jwUaAb_tDd6Mbgp7F9xlQTI4iestE_GuTlBBqwwrxCZSHPzFcFXUEpWuEVDGVY4DVqSaPOmXcJRW3Drp5pDkMpjg3Y1gVqcFIieUBVMFwjImS2RvSGsWoAyUsYvsI_MAysI8_yfNuZeY7tuUFgwGcYWjP3yLdN1_Jl5PiBab8b8KXbwDyaufbMOnYs27OsIPA8A3LWPmy2WrgoG8bP9ZnfHf2GPPpVN1qcy_cD85i1tJFKlj3UnHY8jXr_C5RA8AI)

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation.html) for contract compilation and deployment
- Ethereum wallet with Sepolia ETH and Arbitrum Sepolia ETH for gas
- RLC tokens on Sepolia testnet for bridge testing

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

Instead of duplicating code that may become outdated, here are links to the key contracts in the repository:

- [RLCAdapter.sol](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/main/src/RLCAdapter.sol) - Ethereum-side adapter that wraps the existing RLC token
- [RLCOFT.sol](https://github.com/iExecBlockchainComputing/rlc-multichain/blob/main/src/RLCOFT.sol) - Arbitrum-side token that implements the OFT standard

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

Both RLCAdapter and RLCOFT contracts are implemented using the UUPS pattern, allowing for seamless contract upgrades while maintaining the same proxy address.

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

#### 2. Validation (Testnets)

Always validate upgrades before execution:

```bash
# Validate RLCAdapter upgrade
make validate-adapter-upgrade RPC_URL=$(SEPOLIA_RPC_URL)

# Validate RLCOFT upgrade  
make validate-oft-upgrade RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
```

#### 3. Live Network Upgrades

Execute upgrades on testnets:

```bash
make upgrade-on-testnets
```

### Upgrade Safety Features

- **Automatic Validation**: All upgrade commands automatically validate compatibility first
- **OpenZeppelin Checks**: Uses OpenZeppelin's upgrade safety validations
- **Storage Layout Protection**: Prevents storage slot conflicts between versions
- **Constructor Validation**: Ensures new implementations have compatible constructors

## Usage

### Bridge RLC

A. To send RLC tokens from Ethereum Sepolia to Arbitrum Sepolia:

```bash
make send-tokens-to-arbitrum-sepolia
```

This will:

1. Approve the RLCAdapter to spend your RLC tokens
2. Initiate the cross-chain transfer through LayerZero
3. Lock tokens in the adapter and mint equivalent tokens on Arbitrum

B. To send RLC tokens from Arbitrum Sepolia back to Ethereum Sepolia:

```bash
make send-tokens-to-sepolia
```

This will:

1. Burn RLCOFT tokens on Arbitrum
2. Send a cross-chain message to the adapter
3. Release the original RLC tokens on Ethereum

## How It Works

1. **Ethereum → Arbitrum:**
   - User approves RLCAdapter to spend RLC tokens
   - RLCAdapter locks the RLC tokens
   - LayerZero delivers a message to RLCOFT
   - RLCOFT mints equivalent tokens to the recipient on Arbitrum

2. **Arbitrum → Ethereum:**
   - User initiates transfer from RLCOFT
   - RLCOFT burns the tokens
   - LayerZero delivers a message to RLCAdapter
   - RLCAdapter unlocks the original RLC tokens to the recipient on Ethereum

## Verification

Verify your deployed contracts on block explorers:

```bash
# Verify all contracts (implementations and proxies)
make verify-all

# Verify specific components
make verify-adapter        # Both implementation and proxy
make verify-oft           # Both implementation and proxy
make verify-implementations # Only implementations
make verify-proxies       # Only proxies
```

## Security Considerations

- The bridge security relies on LayerZero's security model
- Administrative functions are protected by the Ownable pattern
- UUPS upgrade authorization is restricted to contract owners only
- Use caution when setting trusted remotes to prevent unauthorized cross-chain interactions
- Always test upgrades thoroughly on testnets before deploying to mainnet
- Upgrade safety is enforced through OpenZeppelin's upgrade validation

## Emergency Controls: Dual-Pause System

Both the RLCAdapter and IexecLayerZeroBridge implement a sophisticated **dual-pause emergency system** designed to handle different types of security incidents while minimizing user impact.

### 🚨 Pause Levels

#### Level 1: Complete Pause (`pause()`)
**Use Case**: Critical security incidents requiring immediate complete shutdown
- **Blocks**: ❌ All bridge operations (incoming and outgoing transfers)
- **Allows**: ✅ Admin functions, view functions
- **Emergency**: Maximum protection - complete bridge shutdown

#### Level 2: Entrance Pause (`pauseEntrances()`)
**Use Case**: Destination chain issues, network congestion, or controlled maintenance
- **Blocks**: ❌ Outgoing transfers only (users can't send tokens out)
- **Allows**: ✅ Incoming transfers (users can still receive tokens and withdraw)
- **Benefit**: Users aren't trapped - they can still exit their positions

## Gas Costs and Fees

LayerZero transactions require fees to cover:

1. Gas on the source chain
2. Gas on the destination chain (prepaid)
3. LayerZero relayer fees

The scripts automatically calculate these fees and include them in the transaction.

## Troubleshooting

## References

- [LayerZero Documentation](https://layerzero.gitbook.io/docs/)
- [OFT Contracts](https://github.com/LayerZero-Labs/solidity-examples/tree/main/contracts/token/oft)
- [OpenZeppelin UUPS Proxy Pattern](https://docs.openzeppelin.com/contracts/5.x/api/proxy#UUPSUpgradeable)
- [OpenZeppelin Upgrade Safety](https://docs.openzeppelin.com/upgrades-plugins/1.x/writing-upgradeable)
- [iExec Platform Documentation](https://docs.iex.ec/)

## TODO:
- Use an entreprise RPC URL for `secrets.SEPOLIA_RPC_URL` in Github environment `ci`.
