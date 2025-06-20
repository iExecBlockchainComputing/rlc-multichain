# Changelog

## 1.0.0 (2025-06-20)


### 🚀 Features

* add forge-std submodule ([4ed744e](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/4ed744ee8407ad3f76cf9d90887904549a55ca6c))
* add local coverage ([#34](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/34)) ([ca269b5](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/ca269b5cd310cf71fbb6b10327aeceae8b2618f7))
* Add partial pause only for send operation ([#29](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/29)) ([1ecd720](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/1ecd720a44d22cd1b1a841c77508042e3f4fd879))
* add upgrade scripts ([#22](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/22)) ([be1f7bd](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/be1f7bd1a1099de36f3d16652c7f3ad054502c0a))
* createX ([#11](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/11)) ([901ad5a](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/901ad5ab3bdacb6552430afd953e1fe8efd16e11))
* fix script folder ([#28](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/28)) ([61afbf6](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/61afbf670346892f227ca7d42ef5b165a0ac5095))
* Implement ERC7802#crosschainMint ([#33](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/33)) ([0f31598](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/0f3159889339b275251901a592e0509d85d29691))
* Init external crosschain RLC token ([#27](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/27)) ([68c17ba](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/68c17bae2fea68ebf66a8e76c80ece982134c85b))
* Init unit tests ([#7](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/7)) ([4a32a1d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/4a32a1d7135ac7504934259898833f6f27af8c22))
* Make OFT contract pausable ([#9](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/9)) ([3403512](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/3403512dd630ef286a258015b5cf1eb4db46d336))
* move Bridge logic from `RLCOFT` to `IexecLayerZeroBridge` contract ([#23](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/23)) ([8361e30](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/8361e30d3030851cf0da909d68a7303cf2cbe1cd))


### 🐞 Bug Fixes

* skipChecks options ([#32](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/32)) ([56f6310](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/56f6310b9c0a7a56f8c88f7571843d30be4b906e))
* some-fixes ([#19](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/19)) ([344d5e0](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/344d5e0873274c47d08bd1519ed8c8df620baaee))
* update submodule path for forge-std and add .gitignore ([fa65f4d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/fa65f4d0ed33fea681720cf67179e9b1de690cde))


### ✨ Polish

* Clean & add TODOs ([#24](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/24)) ([145680d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/145680d47e1a7f8349c032353cb5ae7d726b549e))
* repo architecture ([#30](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/30)) ([46475d2](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/46475d2e6e2b7988c52a48fc4635439587cf80fd))
* Unit Tests for `IexecLayerzeroBridge` in `RLCOFT`contract test ([#25](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/25)) ([46f639d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/46f639dfab279c61d0b603c6bac6d31b85af530c))


### 🧰 Other

* forge init ([7cf1645](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/7cf1645f51592f88b7f7e5b06d7acec69f2c9949))

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
