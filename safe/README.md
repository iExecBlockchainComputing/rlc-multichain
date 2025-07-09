# Safe Multisig Integration

This directory contains tools for integrating the RLC Multichain Bridge with Safe multisig wallets. It provides a TypeScript-based CLI interface for proposing, confirming, and managing Safe transactions.

## Setup

1. **Install dependencies:**
   ```bash
   npm install
   ```

2. **Configure environment:**
   Copy the `.env.safe` template and fill in your values:
   ```bash
   cp .env.safe.template .env.safe
   ```

   Required environment variables:
   - `RPC_URL`: RPC endpoint for your network
   - `CHAIN_ID`: Chain ID (e.g., 1 for Ethereum mainnet, 11155111 for Sepolia)
   - `SAFE_ADDRESS`: Your Safe multisig address
   - `PROPOSER_1_ADDRESS` & `PROPOSER_1_PRIVATE_KEY`: Proposer credentials for proposing transactions
   - `SAFE_API_KEY`: API key for Safe Transaction Service (required for authentication and rate limiting)

3. **Get a Safe API Key:**
   Visit [Safe API Documentation](https://docs.safe.global/core-api/how-to-use-api-keys) to obtain your API key.

## Available Commands

### 1. Propose Transaction
Propose a new transaction to the Safe multisig:

```bash
# Basic ETH transfer
npm run propose-tx -- --to 0x1234567890123456789012345678901234567890 --value 1000000000000000000

# Contract call with data
npm run propose-tx -- --to 0x1234567890123456789012345678901234567890 --data 0xa9059cbb...

# Delegate call
npm run propose-tx -- --to 0x1234567890123456789012345678901234567890 --data 0xa9059cbb... --operation delegatecall
```

### 2. List Transactions
List transactions in various states:

```bash
# List pending transactions
npm run list-pending

# List all transactions
npm run list-pending -- --type all

# List with limit
npm run list-pending -- --type pending --limit 5

# List other types
npm run list-pending -- --type incoming
npm run list-pending -- --type multisig
npm run list-pending -- --type module
```

### 3. Bridge-Specific Operations
Specialized commands for RLC Bridge operations:

```bash
# Upgrade a UUPS proxy contract
npm run bridge-tx -- --operation upgrade --contract 0x1234...5678 --implementation 0xabcd...ef00

# Upgrade with initialization data
npm run bridge-tx -- --operation upgrade --contract 0x1234...5678 --implementation 0xabcd...ef00 --upgrade-data 0x1234...

# Pause a contract
npm run bridge-tx -- --operation pause --contract 0x1234...5678

# Unpause a contract
npm run bridge-tx -- --operation unpause --contract 0x1234...5678

# Set new admin
npm run bridge-tx -- --operation set-admin --contract 0x1234...5678 --new-admin 0xabcd...ef00

# Transfer ERC20 tokens
npm run bridge-tx -- --operation transfer --contract 0x1234...5678 --to 0xabcd...ef00 --amount 1000000000000000000

# Approve ERC20 tokens
npm run bridge-tx -- --operation approve --contract 0x1234...5678 --spender 0xabcd...ef00 --amount 1000000000000000000
```

### 4. Bridge Configuration Workflow
A comprehensive workflow for configuring the RLC Bridge via Safe multisig:

```bash
# Configure bridge from Sepolia to Arbitrum Sepolia
npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL

# Dry run to see what transactions would be proposed
npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL --dry-run

# Configure with a different script
npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL --script ConfigureRLCAdapter
```

**Make targets for convenience:**
```bash
# Configure bridge (one direction)
make safe-configure-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$SEPOLIA_RPC_URL

# Configure bridge (both directions)
make safe-configure-bridge-bidirectional SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia SOURCE_RPC=$SEPOLIA_RPC_URL TARGET_RPC=$ARBITRUM_SEPOLIA_RPC_URL

# Common network pairs
make safe-configure-sepolia-arbitrum
make safe-configure-mainnet-arbitrum

# Show all Safe targets
make safe-help
```

**How it works:**
1. Runs the Foundry configuration script on a fork
2. Reads the generated `broadcast/*/run-latest.json` file
3. Extracts all CALL transactions from the broadcast
4. Proposes each transaction to your Safe multisig
5. Provides Safe transaction hashes for review and execution

## Architecture

### Core Components

1. **SafeManager** (`safe-manager.ts`): Main interface for Safe API interactions
2. **RLCBridgeTransactions** (`bridge-transactions.ts`): Bridge-specific transaction builders
3. **Configuration** (`config.ts`): Environment variable management

### CLI Scripts

1. **propose-transaction.ts**: Generic transaction proposal
2. **list-pending.ts**: Transaction listing and status
3. **bridge-operations.ts**: Bridge-specific operations

## Workflow

1. **Propose**: Create a new transaction proposal using one of the CLI commands
2. **Review**: Check the transaction in Safe's web interface
3. **Confirm**: Collect required signatures from other owners using the Safe UI
4. **Execute**: Once threshold is reached, execute the transaction through the Safe UI

## Security Considerations

- Private keys are loaded from environment variables - keep `.env.safe` secure
- Always review transaction data before confirming
- Use hardware wallets when possible for owner accounts
- Test on testnets before mainnet operations
- Keep API keys secure and don't commit them to version control

## Common Use Cases

### Contract Upgrades
```bash
# Upgrade RLC Liquidity Unifier
npm run bridge-tx -- --operation upgrade --contract 0x7C84A73D0eBb7b2Db5160d34D812DC8632eE99DA --implementation 0x...

# Upgrade with initialization
npm run bridge-tx -- --operation upgrade --contract 0x7C84A73D0eBb7b2Db5160d34D812DC8632eE99DA --implementation 0x... --upgrade-data 0x...
```

### Emergency Controls
```bash
# Pause bridge operations
npm run bridge-tx -- --operation pause --contract 0xcF9A304C10bCfB7f00b290B6B6efa7DB071b4d0F

# Unpause bridge operations
npm run bridge-tx -- --operation unpause --contract 0xcF9A304C10bCfB7f00b290B6B6efa7DB071b4d0F
```

### Token Management
```bash
# Transfer RLC tokens
npm run bridge-tx -- --operation transfer --contract 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd --to 0x... --amount 1000000000000000000

# Approve bridge for token spending
npm run bridge-tx -- --operation approve --contract 0x26A738b6D33EF4D94FF084D3552961b8f00639Cd --spender 0x7C84A73D0eBb7b2Db5160d34D812DC8632eE99DA --amount 1000000000000000000
```

## Troubleshooting

### Common Issues

1. **Network Connection**: Ensure RPC_URL is accessible
2. **Transaction Nonce**: If transactions fail, check for pending transactions
3. **Gas Estimation**: Some operations may require manual gas estimation
4. **API Rate Limits**: Consider using a custom Safe Transaction Service URL

### Error Messages

- "Cannot find module": Run `npm install`
- "Environment validation failed": Check `.env.safe` configuration
- "Transaction already exists": The transaction may already be proposed
- "Insufficient signatures": More confirmations needed before execution

## Development

To extend the functionality:

1. Add new transaction builders to `bridge-transactions.ts`
2. Create new CLI commands following the existing pattern
3. Update the package.json scripts section
4. Add proper error handling and validation

### Testing

```bash
# Build TypeScript
npm run build

# Test environment configuration
npm run list-pending -- --help
```

## References

- [Safe Global Documentation](https://docs.safe.global/)
- [Safe API Kit](https://docs.safe.global/sdk/api-kit)
- [Safe Protocol Kit](https://docs.safe.global/sdk/protocol-kit)
- [Safe Transaction Service](https://docs.safe.global/core-api)
