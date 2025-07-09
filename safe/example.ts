#!/usr/bin/env ts-node

/**
 * Example usage of the Safe integration for RLC Bridge operations
 * This script demonstrates how to use the Safe integration programmatically
 */

import { SafeManager } from './safe-manager';
import { RLCBridgeTransactions } from './bridge-transactions';
import { validateEnvironment } from './config';

async function exampleUsage() {
  try {
    // Validate environment setup
    console.log('🔍 Validating environment configuration...');
    
    try {
      validateEnvironment();
      console.log('✅ Environment validation passed');
    } catch (error) {
      console.log('⚠️  Environment not fully configured - this is expected for the example');
      console.log('   Please copy .env.safe.template to .env.safe and configure it to use the full functionality');
    }
    console.log('');

    // Example 1: Show what configuration is needed
    console.log('📋 Required configuration for Safe integration:');
    console.log('   - SAFE_ADDRESS: Your Safe multisig address');
    console.log('   - RPC_URL: Network RPC endpoint');
    console.log('   - SAFE_API_KEY: API key for Safe Transaction Service');
    console.log('   - PROPOSER_1_ADDRESS & PROPOSER_1_PRIVATE_KEY: Proposer credentials for proposing transactions');
    console.log('');

    // Initialize components (will work even without full config for transaction building)
    const bridgeTransactions = new RLCBridgeTransactions();

    // Example 2: Create sample transaction data (doesn't require network connection)
    console.log('🔧 Creating example transaction data...');
    
    // Example: Pause contract transaction
    const pauseTransaction = bridgeTransactions.createPauseTransaction(
      '0x1234567890123456789012345678901234567890' // Example contract address
    );
    
    console.log('Example pause transaction data:');
    console.log(JSON.stringify(pauseTransaction, null, 2));
    console.log('');

    // Example: ERC20 transfer transaction
    const transferTransaction = bridgeTransactions.createERC20TransferTransaction(
      '0x1234567890123456789012345678901234567890', // Token address
      '0x0987654321098765432109876543210987654321', // Recipient
      '1000000000000000000' // 1 token (18 decimals)
    );
    
    console.log('Example ERC20 transfer transaction data:');
    console.log(JSON.stringify(transferTransaction, null, 2));
    console.log('');

    // Example: Contract upgrade transaction
    const upgradeTransaction = bridgeTransactions.createUpgradeTransaction(
      '0x1234567890123456789012345678901234567890', // Proxy address
      '0x0987654321098765432109876543210987654321', // New implementation
      '0x' // No initialization data
    );
    
    console.log('Example upgrade transaction data:');
    console.log(JSON.stringify(upgradeTransaction, null, 2));
    console.log('');

    console.log('✅ Example completed successfully!');
    console.log('');
    console.log('💡 To actually use these transactions:');
    console.log('   1. Copy .env.safe.template to .env.safe');
    console.log('   2. Configure your Safe address and owner credentials');
    console.log('   3. Use the CLI commands to propose transactions:');
    console.log('      npm run bridge-tx -- --operation pause --contract 0x...');
    console.log('      npm run bridge-tx -- --operation transfer --contract 0x... --to 0x... --amount 1000000000000000000');
    console.log('      npm run bridge-tx -- --operation upgrade --contract 0x... --implementation 0x...');
    console.log('   4. Use the Safe web interface (https://app.safe.global/) to confirm and execute transactions');

  } catch (error) {
    console.error('❌ Error in example usage:', error);
    process.exit(1);
  }
}

// Run the example if this file is executed directly
if (require.main === module) {
  exampleUsage();
}

export { exampleUsage };
