**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [assembly](#assembly) (1 results) (Informational)
 - [dead-code](#dead-code) (1 results) (Informational)
 - [naming-convention](#naming-convention) (7 results) (Informational)
## assembly
Impact: Informational
Confidence: High
 - [ ] ID-0
[DualPausableUpgradeable._getDualPausableStorage()](src/bridges/common/DualPausableUpgradeable.sol#L34-L38) uses assembly
	- [INLINE ASM](src/bridges/common/DualPausableUpgradeable.sol#L35-L37)

src/bridges/common/DualPausableUpgradeable.sol#L34-L38


## dead-code
Impact: Informational
Confidence: Medium
 - [ ] ID-1
[DualPausableUpgradeable.__DualPausable_init_unchained()](src/bridges/common/DualPausableUpgradeable.sol#L90) is never used and should be removed

src/bridges/common/DualPausableUpgradeable.sol#L90


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-2
Parameter [IexecLayerZeroBridge.initialize(address,address)._pauser](src/bridges/layerZero/IexecLayerZeroBridge.sol#L73) is not in mixedCase

src/bridges/layerZero/IexecLayerZeroBridge.sol#L73


 - [ ] ID-3
Variable [IexecLayerZeroBridge.RLC_TOKEN](src/bridges/layerZero/IexecLayerZeroBridge.sol#L52) is not in mixedCase

src/bridges/layerZero/IexecLayerZeroBridge.sol#L52


 - [ ] ID-4
Parameter [IexecLayerZeroBridge.initialize(address,address)._owner](src/bridges/layerZero/IexecLayerZeroBridge.sol#L73) is not in mixedCase

src/bridges/layerZero/IexecLayerZeroBridge.sol#L73


 - [ ] ID-5
Function [DualPausableUpgradeable.__DualPausable_init_unchained()](src/bridges/common/DualPausableUpgradeable.sol#L90) is not in mixedCase

src/bridges/common/DualPausableUpgradeable.sol#L90


 - [ ] ID-6
Parameter [RLCAdapter.initialize(address,address)._pauser](src/bridges/layerZero/RLCAdapter.sol#L58) is not in mixedCase

src/bridges/layerZero/RLCAdapter.sol#L58


 - [ ] ID-7
Parameter [RLCAdapter.initialize(address,address)._owner](src/bridges/layerZero/RLCAdapter.sol#L58) is not in mixedCase

src/bridges/layerZero/RLCAdapter.sol#L58


 - [ ] ID-8
Function [DualPausableUpgradeable.__DualPausable_init()](src/bridges/common/DualPausableUpgradeable.sol#L86-L88) is not in mixedCase

src/bridges/common/DualPausableUpgradeable.sol#L86-L88


