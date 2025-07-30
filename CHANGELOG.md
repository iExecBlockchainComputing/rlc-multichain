# Changelog

## [0.2.0-rc](https://github.com/iExecBlockchainComputing/rlc-multichain/compare/v0.1.0...v0.2.0-rc) (2025-07-30)


### 🚀 Features

* `liquidityUnifier` upgrade script and tests ([#47](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/47)) ([035840e](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/035840e2eaeef5e11acf36247f284f46f75cf70e))
* Add approveAndCall function ([#45](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/45)) ([d05b70f](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/d05b70f71668b3f49c9de8bf6210bd49c457832f))
* add Codecov and Slither integration to CI workflow ([#35](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/35)) ([7469e9a](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/7469e9a37b1bd77110417ccb49fc4787b603cf80))
* add deploy workflow for contract deployment ([#79](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/79)) ([3c7288e](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/3c7288ed15e8618a751a8a36e9deea3311339da8))
* add forge-std submodule ([4ed744e](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/4ed744ee8407ad3f76cf9d90887904549a55ca6c))
* Add LiquidityUnifier and LiquidityUnifierScript test contracts ([#44](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/44)) ([706f4a0](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/706f4a059c68618f41ca2556ee05316ed316e25d))
* add local coverage ([#34](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/34)) ([ca269b5](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/ca269b5cd310cf71fbb6b10327aeceae8b2618f7))
* Add partial pause only for send operation ([#29](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/29)) ([1ecd720](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/1ecd720a44d22cd1b1a841c77508042e3f4fd879))
* add unit tests for internal `_credit` function ([#62](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/62)) ([8c72922](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/8c72922f2122e0a5e58096a51ce9b4d1c78d7ae3))
* add unit tests for internal `_debit` function ([#66](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/66)) ([8ccc0e4](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/8ccc0e461981170f7a340104d848dfd4a0e5ed6e))
* add upgrade scripts ([#22](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/22)) ([be1f7bd](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/be1f7bd1a1099de36f3d16652c7f3ad054502c0a))
* Add upgrader address to IexecLayerZeroBridge contract & clean code ([#48](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/48)) ([11d9884](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/11d9884b2d46463adcafd8107b3b7c13954a1370))
* configuring bridges contracts on CI ([#81](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/81)) ([09761d4](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/09761d4bb9c252a6ca9a0020d2ad7979ec9ae75f))
* createX ([#11](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/11)) ([901ad5a](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/901ad5ab3bdacb6552430afd953e1fe8efd16e11))
* Deploy on testnets ([#63](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/63)) ([a2a1cfd](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/a2a1cfdf2050c92a82dbe16a1770b4b0b5599288))
* Deploy on testnets ([#74](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/74)) ([1862ccc](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/1862ccce76e3077412241ca217c5164be3f92537))
* fix script folder ([#28](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/28)) ([61afbf6](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/61afbf670346892f227ca7d42ef5b165a0ac5095))
* generalise config lib for deployment and scripts ([#54](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/54)) ([591c312](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/591c312cf62aa6b052e5076662a110bae9ec4697))
* Implement ERC7802#crosschainBurn ([#37](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/37)) ([d9010ab](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/d9010abb4afaeb83b2b836372e1eb5180b4cf35a))
* Implement ERC7802#crosschainMint ([#33](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/33)) ([0f31598](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/0f3159889339b275251901a592e0509d85d29691))
* Implement LiquidityUnifier ([#38](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/38)) ([88d94bf](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/88d94bf37cece2777d7eca9061646b2e8b6966e0))
* increase gas limit for receiving executor in enforced options ([#83](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/83)) ([5548a79](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/5548a79448cec41d437c830c834a042c59ea7ccf))
* Init external crosschain RLC token ([#27](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/27)) ([68c17ba](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/68c17bae2fea68ebf66a8e76c80ece982134c85b))
* Init unit tests ([#7](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/7)) ([4a32a1d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/4a32a1d7135ac7504934259898833f6f27af8c22))
* Make OFT contract pausable ([#9](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/9)) ([3403512](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/3403512dd630ef286a258015b5cf1eb4db46d336))
* move Bridge logic from `RLCOFT` to `IexecLayerZeroBridge` contract ([#23](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/23)) ([8361e30](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/8361e30d3030851cf0da909d68a7303cf2cbe1cd))
* Override access control functions to have a consistent state in the bridge contract ([#77](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/77)) ([90e0be9](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/90e0be9485a6c938df240fddb801bc91774abd31))
* prepare audit fix ([#46](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/46)) ([74e5478](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/74e5478b84bcf7fc7dd53423eaba508ea421725c))
* prepare audit with automate audit report ([#36](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/36)) ([f880c4d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/f880c4d7867e056b1e41c5445de672d52438e4a1))
* re add verification script ([#80](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/80)) ([9029aa7](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/9029aa7ec207f55405f8e00ab5d6b9c220b5bddf))
* Restore SafeERC20 use & check for zero addresses in LiquidityUnifier ([#51](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/51)) ([5da9183](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/5da9183b9e6b075e9e9e6271bb790b126e5d9795))
* update config on deploy ([#56](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/56)) ([01051e3](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/01051e39369737240d61ed6fd9b3916320fce362))
* update readme ([#60](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/60)) ([3719483](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/37194839ffbe9b5b8265b98f5788aa47591c580a))
* Update workflow to be compatible with Stargate UI ([#53](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/53)) ([ac0c654](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/ac0c6542e8fcf98a1144b8c5949eaa4ed4f09bab))
* use config file ([#52](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/52)) ([70c70d2](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/70c70d23e27ba64a1216dfa0b81e4b23fee3c049))
* Use modifier instead of manual check ([#70](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/70)) ([604759c](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/604759cbc85fa35ed38f71cf41cc1732551976f2))


### 🐞 Bug Fixes

* configure send scripts ([#75](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/75)) ([0d0c9e7](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/0d0c9e78c275bcff9178396e159a7bbe672052c1))
* Fix "outbound" spelling typo ([#78](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/78)) ([83d1069](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/83d10690cfb4dd41f33d81f18f45d17fe69bb33a))
* Restore implementation deployment using CreateX ([#72](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/72)) ([166593c](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/166593ccdf71d4463fc67017c355fa032ec18619))
* skipChecks options ([#32](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/32)) ([56f6310](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/56f6310b9c0a7a56f8c88f7571843d30be4b906e))
* some-fixes ([#19](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/19)) ([344d5e0](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/344d5e0873274c47d08bd1519ed8c8df620baaee))
* somes-fixes ([#61](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/61)) ([23881a7](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/23881a7cb1f95d87fae12e6aa833da869c6586ba))
* update submodule path for forge-std and add .gitignore ([fa65f4d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/fa65f4d0ed33fea681720cf67179e9b1de690cde))


### ✨ Polish

* Clean & add TODOs ([#24](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/24)) ([145680d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/145680d47e1a7f8349c032353cb5ae7d726b549e))
* Clean some TODOs ([#59](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/59)) ([e45e89d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/e45e89d2b74018386866544b530e980898300784))
* Remove some code to optimize gas consumption ([#49](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/49)) ([4eb3634](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/4eb3634e6f12a3d1d2aff62489debd4b46c7c467))
* remove unused test for RLCAdapter ([#58](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/58)) ([1b33286](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/1b332861fb0b8826a2f173989e2529cddf79f84c))
* Rename `pauseSend` by `pauseOutboundTransfers` ([#65](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/65)) ([c539514](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/c539514076f8f4f751ce4215ca364af4731912c2))
* repo architecture ([#30](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/30)) ([46475d2](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/46475d2e6e2b7988c52a48fc4635439587cf80fd))
* Unit Tests for `IexecLayerzeroBridge` in `RLCOFT`contract test ([#25](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/25)) ([46f639d](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/46f639dfab279c61d0b603c6bac6d31b85af530c))
* Use ERC20Bridgeable from Openzeppelin ([#55](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/55)) ([e358fef](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/e358fefc969899183e5a4d8cc93982735d62b74d))


### 🧰 Other

* forge init ([7cf1645](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/7cf1645f51592f88b7f7e5b06d7acec69f2c9949))


### 🧪 Tests

* Clean RLCCrosschain tests ([#42](https://github.com/iExecBlockchainComputing/rlc-multichain/issues/42)) ([bdfe771](https://github.com/iExecBlockchainComputing/rlc-multichain/commit/bdfe771f6e37b642ec8d78969ce519b5ecc4c906))

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
