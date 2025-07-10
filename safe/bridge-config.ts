#!/usr/bin/env ts-node

import { SafeManager } from './safe-manager';
import { validateEnvironment } from './config';
import { spawn } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

interface BroadcastTransaction {
  hash: string;
  transactionType: string;
  contractName: string | null;
  contractAddress: string;
  function: string;
  arguments: any[];
  transaction: {
    from: string;
    to: string;
    gas: string;
    value: string;
    input: string;
    nonce: string;
    chainId: string;
  };
  additionalContracts: any[];
  isFixedGasLimit: boolean;
}

interface BroadcastFile {
  transactions: BroadcastTransaction[];
  receipts: any[];
  libraries: any[];
  pending: any[];
  returns: any;
  timestamp: number;
  chain: number;
  multi: boolean;
  commit: string;
}

interface BridgeConfigArgs {
  sourceChain: string;
  targetChain: string;
  rpcUrl: string;
  scriptName: string;
  dryRun?: boolean;
  forgeOptions?: string;
}

export class BridgeConfigurator {
  private safeManager: SafeManager;

  constructor() {
    this.safeManager = new SafeManager();
  }

  /**
   * Main method to configure bridge and propose transactions to Safe
   */
  async configureBridge(args: BridgeConfigArgs): Promise<void> {
    console.log(`🔧 Configuring bridge ${args.sourceChain} -> ${args.targetChain}`);
    
    try {
      let chainId: string;
      let useExistingBroadcast = false;
      
      // Step 1: Try to run the Foundry script
      console.log('📡 Running Foundry configuration script...');
      try {
        chainId = await this.runFoundryScript(args);
      } catch (foundryError) {
        console.warn('⚠️  Foundry script failed, checking for existing broadcast file...');
        chainId = this.getChainIdFromRpc(args.rpcUrl);
        useExistingBroadcast = true;
        
        // Check if broadcast file exists before continuing
        const broadcastPath = path.join(
          process.cwd(),
          'broadcast',
          `${args.scriptName}.s.sol`,
          chainId,
          'run-latest.json'
        );
        
        if (!fs.existsSync(broadcastPath)) {
          console.error('❌ Foundry script failed and no existing broadcast file found.');
          console.error('Common issues:');
          console.error('   - Invalid RPC URL or network issues');
          console.error('   - Missing environment variables (ACCOUNT, etc.)');
          console.error('   - Contract not deployed or configuration issues');
          throw foundryError;
        }
        
        console.log('✅ Found existing broadcast file, continuing...');
      }
      
      // Step 2: Read broadcast file
      console.log('📄 Reading broadcast transactions...');
      const transactions = await this.readBroadcastFile(args.scriptName, chainId);
      
      if (transactions.length === 0) {
        console.log('ℹ️  No transactions found in broadcast file');
        return;
      }

      console.log(`📋 Found ${transactions.length} transactions to propose`);
      
      if (useExistingBroadcast) {
        console.log('ℹ️  Note: Using existing broadcast file due to Foundry script failure');
      }
      
      // Step 3: Propose transactions to Safe
      if (args.dryRun) {
        console.log('🏃 DRY RUN - Transactions that would be proposed:');
        this.displayTransactions(transactions);
      } else {
        console.log('🔐 Proposing transactions to Safe...');
        await this.proposeTransactionsToSafe(transactions);
      }

    } catch (error) {
      console.error('❌ Error configuring bridge:', error);
      throw error;
    }
  }

  /**
   * Run the Foundry script and return the chain ID
   */
  private async runFoundryScript(args: BridgeConfigArgs): Promise<string> {
    return new Promise((resolve, reject) => {
      const makeArgs = [
        'configure-bridge',
        `SOURCE_CHAIN=${args.sourceChain}`,
        `TARGET_CHAIN=${args.targetChain}`,
        `RPC_URL=http://localhost:8545`
      ];

      // Add forge options if provided
      if (args.forgeOptions) {
        // Parse the forge options string and add each option as a separate argument
        const options = args.forgeOptions.trim().split(/\s+/);
        makeArgs.push(`FORGE_OPTIONS=${options.join(' ')}`);
      }

      const makeProcess = spawn('make', makeArgs, {
        cwd: process.cwd(),
        stdio: 'inherit',
        env: { ...process.env }
      });

      makeProcess.on('close', (code) => {
        if (code === 0) {
          // Extract chain ID from RPC URL or use a mapping
          const chainId = this.getChainIdFromRpc(args.rpcUrl);
          resolve(chainId);
        } else {
          reject(new Error(`Make process exited with code ${code}`));
        }
      });

      makeProcess.on('error', (error) => {
        reject(error);
      });
    });
  }

  /**
   * Get chain ID from RPC URL or use default mapping
   */
  private getChainIdFromRpc(rpcUrl: string): string {
    // Common chain ID mappings
    const chainMappings: Record<string, string> = {
      'sepolia': '11155111',
      'arbitrum-sepolia': '421614',
      'ethereum': '1',
      'arbitrum': '42161'
    };

    const url = rpcUrl.toLowerCase();
    for (const [network, chainId] of Object.entries(chainMappings)) {
      if (url.includes(network)) {
        return chainId;
      }
    }

    // Default to Sepolia if can't determine
    console.warn(`⚠️  Could not determine chain ID from RPC URL: ${rpcUrl}, defaulting to Sepolia`);
    return '11155111';
  }

  /**
   * Read the broadcast file and extract transactions
   */
  private async readBroadcastFile(scriptName: string, chainId: string): Promise<BroadcastTransaction[]> {
    const broadcastPath = path.join(
      process.cwd(),
      'broadcast',
      `${scriptName}.s.sol`,
      chainId,
      'run-latest.json'
    );

    if (!fs.existsSync(broadcastPath)) {
      throw new Error(`Broadcast file not found: ${broadcastPath}`);
    }

    const broadcastContent = fs.readFileSync(broadcastPath, 'utf8');
    const broadcastData: BroadcastFile = JSON.parse(broadcastContent);

    return broadcastData.transactions.filter(tx => tx.transactionType === 'CALL');
  }

  /**
   * Display transactions in a readable format
   */
  private displayTransactions(transactions: BroadcastTransaction[]): void {
    transactions.forEach((tx, index) => {
      console.log(`\n📝 Transaction ${index + 1}:`);
      console.log(`   To: ${tx.contractAddress}`);
      console.log(`   Function: ${tx.function}`);
      console.log(`   Value: ${tx.transaction.value}`);
      console.log(`   Data: ${tx.transaction.input}`);
      console.log(`   Gas: ${tx.transaction.gas}`);
    });
  }

  /**
   * Propose transactions to Safe multisig
   */
  private async proposeTransactionsToSafe(transactions: BroadcastTransaction[]): Promise<void> {
    const proposedHashes: string[] = [];

    for (let i = 0; i < transactions.length; i++) {
      const tx = transactions[i];
      
      console.log(`\n🔐 Proposing transaction ${i + 1}/${transactions.length}:`);
      console.log(`   To: ${tx.contractAddress}`);
      console.log(`   Function: ${tx.function}`);
      
      try {
        const transactionData = this.safeManager.createContractCallTransaction(
          tx.contractAddress,
          tx.transaction.input,
          tx.transaction.value
        );

        const safeTxHash = await this.safeManager.proposeTransaction(transactionData);
        proposedHashes.push(safeTxHash);
        
        console.log(`   ✅ Proposed! Safe TX Hash: ${safeTxHash}`);
        
        // Small delay between transactions
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error) {
        console.error(`   ❌ Failed to propose transaction ${i + 1}:`, error);
        throw error;
      }
    }

    console.log('\n🎉 All transactions proposed successfully!');
    console.log('\n📋 Safe Transaction Hashes:');
    proposedHashes.forEach((hash, index) => {
      console.log(`   ${index + 1}. ${hash}`);
    });
    
    console.log('\n🔗 Next steps:');
    console.log('   1. Review the transactions in the Safe web interface');
    console.log('   2. Collect additional signatures from other owners');
    console.log('   3. Execute the transactions once threshold is reached');
  }

  /**
   * Get available scripts from broadcast directory
   */
  static getAvailableScripts(): string[] {
    const broadcastDir = path.join(process.cwd(), 'broadcast');
    if (!fs.existsSync(broadcastDir)) {
      return [];
    }

    return fs.readdirSync(broadcastDir)
      .filter(item => item.endsWith('.s.sol'))
      .map(item => item.replace('.s.sol', ''));
  }

  /**
   * Get available chain IDs for a script
   */
  static getAvailableChains(scriptName: string): string[] {
    const scriptDir = path.join(process.cwd(), 'broadcast', `${scriptName}.s.sol`);
    if (!fs.existsSync(scriptDir)) {
      return [];
    }

    return fs.readdirSync(scriptDir)
      .filter(item => fs.statSync(path.join(scriptDir, item)).isDirectory());
  }
}

// CLI functionality
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
🌉 Safe Bridge Configurator

Usage: npm run bridge-config -- [options]

Options:
  --source-chain <chain>     Source chain name (required)
  --target-chain <chain>     Target chain name (required)
  --rpc-url <url>           RPC URL for the source chain (required)
  --script <name>           Script name (default: IexecLayerZeroBridge)
  --forge-options <options>  Additional forge options (e.g. "--unlocked --sender 0x...") Use = format: --forge-options="value"
  --dry-run                 Show transactions without proposing
  --help                    Show this help message

Examples:
  # Configure bridge from Sepolia to Arbitrum Sepolia
  npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url https://sepolia.infura.io/v3/YOUR_KEY

  # Dry run to see what would be proposed
  npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url https://sepolia.infura.io/v3/YOUR_KEY --dry-run

  # Use with forge options for unlocked accounts
  npm run bridge-config -- --source-chain sepolia --target-chain arbitrum-sepolia --rpc-url http://localhost:8545 --forge-options="--unlocked --sender 0x9990cfb1Feb7f47297F54bef4d4EbeDf6c5463a3"

Available scripts: ${BridgeConfigurator.getAvailableScripts().join(', ')}
    `);
    process.exit(1);
  }

  // Parse arguments
  const config: BridgeConfigArgs = {
    sourceChain: '',
    targetChain: '',
    rpcUrl: '',
    scriptName: 'IexecLayerZeroBridge',
    dryRun: false,
    forgeOptions: undefined
  };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    
    // Handle --forge-options=value format
    if (arg.startsWith('--forge-options=')) {
      config.forgeOptions = arg.substring('--forge-options='.length);
      continue;
    }
    
    switch (arg) {
      case '--source-chain':
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          console.error('❌ Error: --source-chain requires a value');
          process.exit(1);
        }
        config.sourceChain = args[++i];
        break;
      case '--target-chain':
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          console.error('❌ Error: --target-chain requires a value');
          process.exit(1);
        }
        config.targetChain = args[++i];
        break;
      case '--rpc-url':
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          console.error('❌ Error: --rpc-url requires a value');
          process.exit(1);
        }
        config.rpcUrl = args[++i];
        break;
      case '--script':
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          console.error('❌ Error: --script requires a value');
          process.exit(1);
        }
        config.scriptName = args[++i];
        break;
      case '--forge-options':
        if (i + 1 >= args.length || args[i + 1].startsWith('--')) {
          console.error('❌ Error: --forge-options requires a value');
          process.exit(1);
        }
        config.forgeOptions = args[++i];
        break;
      case '--dry-run':
        config.dryRun = true;
        break;
      case '--help':
        console.log('Help message already shown above');
        process.exit(0);
      default:
        console.error(`Unknown argument: ${arg}`);
        process.exit(1);
    }
  }

  // Validate required arguments
  if (!config.sourceChain || !config.targetChain || !config.rpcUrl) {
    console.error('❌ Error: --source-chain, --target-chain, and --rpc-url are required');
    process.exit(1);
  }

  try {
    // Validate environment
    validateEnvironment();
    
    const configurator = new BridgeConfigurator();
    await configurator.configureBridge(config);
    
  } catch (error) {
    console.error('❌ Configuration failed:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
