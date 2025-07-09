import { SafeManager } from './safe-manager';
import { MetaTransactionData } from '@safe-global/types-kit';

/**
 * Bridge-specific transaction builders for RLC Multichain operations
 */
export class RLCBridgeTransactions {
  private safeManager: SafeManager;

  constructor() {
    this.safeManager = new SafeManager();
  }

  /**
   * Create a transaction to upgrade a contract using UUPS proxy
   */
  createUpgradeTransaction(
    proxyAddress: string,
    newImplementation: string,
    upgradeData: string = '0x'
  ): MetaTransactionData {
    // Standard UUPS upgrade function selector: upgradeTo(address)
    const upgradeToSelector = '0x3659cfe6';
    // If upgradeData is provided, use upgradeToAndCall: upgradeToAndCall(address,bytes)
    const upgradeToAndCallSelector = '0x4f1ef286';
    
    let data: string;
    if (upgradeData === '0x') {
      // Simple upgrade without initialization
      data = upgradeToSelector + newImplementation.slice(2).padStart(64, '0');
    } else {
      // Upgrade with initialization call
      const implementationPadded = newImplementation.slice(2).padStart(64, '0');
      const dataOffset = '0000000000000000000000000000000000000000000000000000000000000040';
      const dataLength = ((upgradeData.length - 2) / 2).toString(16).padStart(64, '0');
      const dataPadded = upgradeData.slice(2).padEnd(Math.ceil((upgradeData.length - 2) / 64) * 64, '0');
      
      data = upgradeToAndCallSelector + implementationPadded + dataOffset + dataLength + dataPadded;
    }

    return this.safeManager.createContractCallTransaction(proxyAddress, data);
  }

  /**
   * Create a transaction to pause/unpause a contract
   */
  createPauseTransaction(contractAddress: string, pause: boolean = true): MetaTransactionData {
    const selector = pause ? '0x8456cb59' : '0x3f4ba83a'; // pause() or unpause()
    return this.safeManager.createContractCallTransaction(contractAddress, selector);
  }

  /**
   * Create a transaction to set a new admin for a contract
   */
  createSetAdminTransaction(contractAddress: string, newAdmin: string): MetaTransactionData {
    // Assuming a setAdmin(address) function - selector might need adjustment
    const selector = '0x704b6c02'; // Common setAdmin selector
    const data = selector + newAdmin.slice(2).padStart(64, '0');
    return this.safeManager.createContractCallTransaction(contractAddress, data);
  }

  /**
   * Create a transaction to set bridge configuration
   */
  createSetBridgeConfigTransaction(
    bridgeAddress: string,
    chainId: number,
    endpoint: string,
    config: string
  ): MetaTransactionData {
    // This would need to be adjusted based on actual bridge configuration function
    // Placeholder for setPeer or similar configuration function
    const selector = '0x3400288b'; // Example selector for setPeer
    const chainIdPadded = chainId.toString(16).padStart(64, '0');
    const endpointPadded = endpoint.slice(2).padStart(64, '0');
    const configPadded = config.slice(2).padStart(64, '0');
    
    const data = selector + chainIdPadded + endpointPadded + configPadded;
    return this.safeManager.createContractCallTransaction(bridgeAddress, data);
  }

  /**
   * Create a transaction to transfer ERC20 tokens
   */
  createERC20TransferTransaction(
    tokenAddress: string,
    to: string,
    amount: string
  ): MetaTransactionData {
    const selector = '0xa9059cbb'; // transfer(address,uint256)
    const toPadded = to.slice(2).padStart(64, '0');
    const amountPadded = BigInt(amount).toString(16).padStart(64, '0');
    
    const data = selector + toPadded + amountPadded;
    return this.safeManager.createContractCallTransaction(tokenAddress, data);
  }

  /**
   * Create a transaction to approve ERC20 tokens
   */
  createERC20ApprovalTransaction(
    tokenAddress: string,
    spender: string,
    amount: string
  ): MetaTransactionData {
    const selector = '0x095ea7b3'; // approve(address,uint256)
    const spenderPadded = spender.slice(2).padStart(64, '0');
    const amountPadded = BigInt(amount).toString(16).padStart(64, '0');
    
    const data = selector + spenderPadded + amountPadded;
    return this.safeManager.createContractCallTransaction(tokenAddress, data);
  }

  /**
   * Create a batch transaction for multiple operations
   */
  createBatchTransaction(transactions: MetaTransactionData[]): MetaTransactionData[] {
    return transactions;
  }

  /**
   * Helper to propose any of the above transactions
   */
  async proposeTransaction(
    transaction: MetaTransactionData
  ): Promise<string> {
    return await this.safeManager.proposeTransaction(transaction);
  }

  /**
   * Get pending transactions
   */
  async getPendingTransactions() {
    return await this.safeManager.getPendingTransactions();
  }
}
