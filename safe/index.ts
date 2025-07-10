/**
 * Safe Multisig Integration for RLC Multichain Bridge
 * 
 * This module provides a comprehensive integration with Safe multisig wallets
 * for managing RLC Bridge operations securely.
 * 
 * @example
 * ```typescript
 * import { SafeManager, RLCBridgeTransactions } from './safe';
 * 
 * const safeManager = new SafeManager();
 * const bridgeTransactions = new RLCBridgeTransactions();
 * 
 * // Create a pause transaction
 * const pauseTx = bridgeTransactions.createPauseTransaction(contractAddress);
 * 
 * // Propose to Safe
 * const txHash = await bridgeTransactions.proposeTransaction(pauseTx);
 * ```
 */

export { SafeManager } from './safe-manager';
export { getSafeConfig, getProposerConfig, validateEnvironment } from './config';
export type { SafeConfig, OwnerConfig } from './config';

// Re-export useful types from Safe SDK
export type { MetaTransactionData, OperationType } from '@safe-global/types-kit';
