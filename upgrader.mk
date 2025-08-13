#
# Contract upgrade operations
#

# Individual contract upgrades on single chain
upgrade-liquidity-unifier: # CHAIN, RPC_URL, NEW_CONTRACT
	@echo "🔄 Upgrading RLCLiquidityUnifier on $(CHAIN) to $(NEW_CONTRACT)"
	CHAIN=$(CHAIN) forge script script/UpgradeContracts.s.sol:UpgradeRLCLiquidityUnifier \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--sig "run(string)" $(NEW_CONTRACT) \
		-vvv

upgrade-crosschain-token: # CHAIN, RPC_URL, NEW_CONTRACT
	@echo "🔄 Upgrading RLCCrosschainToken on $(CHAIN) to $(NEW_CONTRACT)"
	CHAIN=$(CHAIN) forge script script/UpgradeContracts.s.sol:UpgradeRLCCrosschainToken \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--sig "run(string)" $(NEW_CONTRACT) \
		-vvv

upgrade-bridge: # CHAIN, RPC_URL, NEW_CONTRACT
	@echo "🔄 Upgrading IexecLayerZeroBridge on $(CHAIN) to $(NEW_CONTRACT)"
	CHAIN=$(CHAIN) forge script script/UpgradeContracts.s.sol:UpgradeIexecLayerZeroBridge \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--sig "run(string)" $(NEW_CONTRACT) \
		-vvv

# Multi-contract upgrade on single chain
upgrade-all-contracts: # CHAIN, RPC_URL, NEW_LIQUIDITY_CONTRACT, NEW_CROSSCHAIN_CONTRACT, NEW_BRIDGE_CONTRACT
	@echo "🔄 Upgrading ALL contracts on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/UpgradeContracts.s.sol:UpgradeAllContracts \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		--sig "run(string,string,string)" $(NEW_LIQUIDITY_CONTRACT) $(NEW_CROSSCHAIN_CONTRACT) $(NEW_BRIDGE_CONTRACT) \
		-vvv

# Implementation address monitoring
get-implementation-addresses: # CHAIN, RPC_URL
	@echo "📋 Getting implementation addresses on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/UpgradeContracts.s.sol:GetImplementationAddresses \
		--rpc-url $(RPC_URL) \
		-vvv

get-all-implementation-addresses:
	@echo "📋 Getting implementation addresses on ALL chains"
	forge script script/UpgradeContractsAllChains.s.sol:GetAllImplementationAddresses \
		--rpc-url $(ETHEREUM_RPC_URL) \
		-vvv
