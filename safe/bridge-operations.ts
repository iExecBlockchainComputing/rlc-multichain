#!/usr/bin/env ts-node

import { RLCBridgeTransactions } from './bridge-transactions';
import { validateEnvironment } from './config';

interface BridgeOperationArgs {
  operation: 'upgrade' | 'pause' | 'unpause' | 'set-admin' | 'transfer' | 'approve';
  contract: string;
  // Upgrade specific
  implementation?: string;
  upgradeData?: string;
  // Admin specific
  newAdmin?: string;
  // Transfer/approve specific
  to?: string;
  spender?: string;
  amount?: string;
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0 || args.includes('--help')) {
    console.log(`
Usage: npm run bridge-tx -- --operation <operation> --contract <address> [options]

Operations:
  upgrade        Upgrade a UUPS proxy contract
  pause          Pause a contract
  unpause        Unpause a contract
  set-admin      Set a new admin for a contract
  transfer       Transfer ERC20 tokens
  approve        Approve ERC20 tokens

Common Options:
  --contract <address>     Contract address (required)

Upgrade Options:
  --implementation <addr>  New implementation address (required for upgrade)
  --upgrade-data <data>    Initialization data for upgrade (optional)

Admin Options:
  --new-admin <address>    New admin address (required for set-admin)

Transfer/Approve Options:
  --to <address>           Transfer recipient (required for transfer)
  --spender <address>      Spender address (required for approve)
  --amount <amount>        Amount in wei (required for transfer/approve)

Examples:
  # Upgrade a contract
  npm run bridge-tx -- --operation upgrade --contract 0x1234...5678 --implementation 0xabcd...ef00

  # Pause a contract
  npm run bridge-tx -- --operation pause --contract 0x1234...5678

  # Transfer tokens
  npm run bridge-tx -- --operation transfer --contract 0x1234...5678 --to 0xabcd...ef00 --amount 1000000000000000000

  # Approve tokens
  npm run bridge-tx -- --operation approve --contract 0x1234...5678 --spender 0xabcd...ef00 --amount 1000000000000000000
    `);
    process.exit(0);
  }

  // Parse arguments
  const parsedArgs: BridgeOperationArgs = {
    operation: 'upgrade',
    contract: ''
  };

  for (let i = 0; i < args.length; i += 2) {
    const key = args[i];
    const value = args[i + 1];
    
    switch (key) {
      case '--operation':
        parsedArgs.operation = value as any;
        break;
      case '--contract':
        parsedArgs.contract = value;
        break;
      case '--implementation':
        parsedArgs.implementation = value;
        break;
      case '--upgrade-data':
        parsedArgs.upgradeData = value;
        break;
      case '--new-admin':
        parsedArgs.newAdmin = value;
        break;
      case '--to':
        parsedArgs.to = value;
        break;
      case '--spender':
        parsedArgs.spender = value;
        break;
      case '--amount':
        parsedArgs.amount = value;
        break;
      default:
        console.error(`Unknown argument: ${key}`);
        process.exit(1);
    }
  }

  // Validate required arguments
  if (!parsedArgs.contract) {
    console.error('Error: --contract argument is required');
    process.exit(1);
  }

  try {
    validateEnvironment();
    
    const bridgeTransactions = new RLCBridgeTransactions();
    let transaction;
    
    switch (parsedArgs.operation) {
      case 'upgrade':
        if (!parsedArgs.implementation) {
          console.error('Error: --implementation is required for upgrade operation');
          process.exit(1);
        }
        transaction = bridgeTransactions.createUpgradeTransaction(
          parsedArgs.contract,
          parsedArgs.implementation,
          parsedArgs.upgradeData || '0x'
        );
        break;
        
      case 'pause':
        transaction = bridgeTransactions.createPauseTransaction(parsedArgs.contract, true);
        break;
        
      case 'unpause':
        transaction = bridgeTransactions.createPauseTransaction(parsedArgs.contract, false);
        break;
        
      case 'set-admin':
        if (!parsedArgs.newAdmin) {
          console.error('Error: --new-admin is required for set-admin operation');
          process.exit(1);
        }
        transaction = bridgeTransactions.createSetAdminTransaction(
          parsedArgs.contract,
          parsedArgs.newAdmin
        );
        break;
        
      case 'transfer':
        if (!parsedArgs.to || !parsedArgs.amount) {
          console.error('Error: --to and --amount are required for transfer operation');
          process.exit(1);
        }
        transaction = bridgeTransactions.createERC20TransferTransaction(
          parsedArgs.contract,
          parsedArgs.to,
          parsedArgs.amount
        );
        break;
        
      case 'approve':
        if (!parsedArgs.spender || !parsedArgs.amount) {
          console.error('Error: --spender and --amount are required for approve operation');
          process.exit(1);
        }
        transaction = bridgeTransactions.createERC20ApprovalTransaction(
          parsedArgs.contract,
          parsedArgs.spender,
          parsedArgs.amount
        );
        break;
        
      default:
        console.error(`Unknown operation: ${parsedArgs.operation}`);
        process.exit(1);
    }

    console.log(`Proposing ${parsedArgs.operation} transaction:`);
    console.log(JSON.stringify(transaction, null, 2));
    console.log('');

    const safeTxHash = await bridgeTransactions.proposeTransaction(transaction);
    
    console.log('✅ Bridge transaction proposed successfully!');
    console.log(`Safe Transaction Hash: ${safeTxHash}`);
    console.log('');
    console.log('Next steps:');
    console.log(`1. Review the transaction in the Safe web interface`);
    console.log(`2. Collect additional signatures from other owners using the Safe UI`);
    console.log(`3. Execute the transaction once threshold is reached through the Safe UI`);

  } catch (error) {
    console.error('❌ Error proposing bridge transaction:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
