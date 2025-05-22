# Changelog

## 1.0.0 (2025-05-22)


### 🚀 Features

* add forge-std submodule ([4ed744e](https://github.com/iExecBlockchainComputing/RLC-multichain/commit/4ed744ee8407ad3f76cf9d90887904549a55ca6c))


### 🐞 Bug Fixes

* update submodule path for forge-std and add .gitignore ([fa65f4d](https://github.com/iExecBlockchainComputing/RLC-multichain/commit/fa65f4d0ed33fea681720cf67179e9b1de690cde))


### 🧰 Other

* forge init ([7cf1645](https://github.com/iExecBlockchainComputing/RLC-multichain/commit/7cf1645f51592f88b7f7e5b06d7acec69f2c9949))

## Changelog

## vNEXT

### Added
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
