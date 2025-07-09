#!/usr/bin/env ts-node

import { BridgeConfigurator } from './bridge-config';
import { SafeManager } from './safe-manager';
import { validateEnvironment } from './config';

/**
 * Comprehensive example demonstrating the bridge configuration workflow
 */
async function bridgeConfigurationExample() {
  console.log('🌉 Bridge Configuration Example');
  console.log('================================\n');

  try {
    // Validate environment first
    validateEnvironment();
    console.log('✅ Environment validation passed\n');

    // Example 1: Dry run to see what would be proposed
    console.log('📝 Example 1: Dry run configuration');
    console.log('-----------------------------------');
    
    const dryRunConfig = {
      sourceChain: 'sepolia',
      targetChain: 'arbitrum_sepolia',
      rpcUrl: process.env.SEPOLIA_RPC_URL || 'https://sepolia.infura.io/v3/YOUR_KEY',
      scriptName: 'IexecLayerZeroBridge',
      dryRun: true
    };

    console.log('Configuration:', dryRunConfig);
    console.log('This will show what transactions would be proposed without actually proposing them.\n');

    // Example 2: Show available scripts
    console.log('📚 Example 2: Available scripts');
    console.log('-------------------------------');
    const availableScripts = BridgeConfigurator.getAvailableScripts();
    console.log('Available scripts:', availableScripts);
    
    // Show available chains for each script
    availableScripts.forEach(script => {
      const chains = BridgeConfigurator.getAvailableChains(script);
      console.log(`  ${script}: chains [${chains.join(', ')}]`);
    });

    console.log('\n📋 Example 3: Manual transaction proposal');
    console.log('-----------------------------------------');
    
    // Example of manually proposing a transaction
    const safeManager = new SafeManager();
    
    // Example transaction data (this would come from broadcast file)
    const exampleTransaction = {
      to: '0x634ad305bb5702b02833c8ba85e1bc656ab56fc4',
      data: '0x3400288b0000000000000000000000000000000000000000000000000000000000009d270000000000000000000000002f133d13d3a424ecb03ee881e578ea8fbb55a000',
      value: '0'
    };

    console.log('Example transaction that would be proposed:');
    console.log(JSON.stringify(exampleTransaction, null, 2));
    console.log('\n🔗 Integration with Make');
    console.log('------------------------');
    console.log('You can use the following Make targets:');
    console.log('');
    console.log('# Configure bridge (one direction)');
    console.log('make safe-configure-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$SEPOLIA_RPC_URL');
    console.log('');
    console.log('# Configure bridge (both directions)');
    console.log('make safe-configure-bridge-bidirectional SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia SOURCE_RPC=$SEPOLIA_RPC_URL TARGET_RPC=$ARBITRUM_SEPOLIA_RPC_URL');
    console.log('');
    console.log('# Common network pairs');
    console.log('make safe-configure-sepolia-arbitrum');
    console.log('make safe-configure-mainnet-arbitrum');
    console.log('');
    console.log('# Show all Safe targets');
    console.log('make safe-help');

    console.log('\n🚀 Workflow Summary');
    console.log('-------------------');
    console.log('1. Run: npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL --dry-run');
    console.log('2. Review the transactions that would be proposed');
    console.log('3. Run without --dry-run to actually propose to Safe');
    console.log('4. Review and approve transactions in Safe UI');
    console.log('5. Execute transactions once threshold is met');

    console.log('\n🔧 Advanced Usage');
    console.log('-----------------');
    console.log('# Use different script');
    console.log('npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL --script ConfigureRLCAdapter');
    console.log('');
    console.log('# Configure multiple components sequentially');
    console.log('npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url $SEPOLIA_RPC_URL --script IexecLayerZeroBridge');
    console.log('npm run bridge-config -- --source-chain sepolia --target-chain sepolia --rpc-url $SEPOLIA_RPC_URL --script ConfigureRLCAdapter');
    console.log('npm run bridge-config -- --source-chain sepolia --target-chain sepolia --rpc-url $SEPOLIA_RPC_URL --script ConfigureRLCOFT');

    console.log('\n✅ Example completed successfully!');
    console.log('You can now use the bridge configuration workflow with your Safe multisig.');

  } catch (error) {
    console.error('❌ Example failed:', error);
    process.exit(1);
  }
}

// Run the example
if (require.main === module) {
  bridgeConfigurationExample();
}

export { bridgeConfigurationExample };
