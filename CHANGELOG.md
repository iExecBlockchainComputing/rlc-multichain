# Changelog

## v1.0.0-rc1 (2025-07-29)

### Features
- Initial implementation of RLC OFT (Optimistic Fungible Token) bridge system
- RLCOFT contract deployed on Arbitrum Sepolia with 9 decimal places
- RLCAdapter contract deployed on Ethereum Sepolia to bridge existing RLC token
- Cross-chain message passing functionality using LayerZero protocol
- Configuration scripts for trustless omnichain communication setup
- Token transfer capabilities between Ethereum Sepolia and Arbitrum Sepolia
- `approveAndCall` function for one-step approval and contract interaction
- Burn capability for RLCOFT tokens
- Comprehensive deployment scripts using Foundry
- Configuration utilities to set trusted remote addresses
- Verification targets for block explorer verification
- End-to-end cross-chain transfer test scripts