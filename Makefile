MAKEFLAGS += --no-print-directory

include tools/report.mk tools/verification.mk
-include .env


#
# Test and utility targets
#

fork-ethereum:
	anvil --fork-url $(ETHEREUM_RPC_URL) --port 8545

fork-arbitrum:
	anvil --fork-url $(ARBITRUM_RPC_URL) --port 8546

fork-sepolia:
	anvil --fork-url $(SEPOLIA_RPC_URL) --port 8545

fork-arbitrum-sepolia:
	anvil --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) --port 8546

test-all:
	make unit-test
	make e2e-test

unit-test:
	FOUNDRY_PROFILE=test forge test -vvv --match-path "./test/units/**" --force

e2e-test:
	FOUNDRY_PROFILE=test forge test -vvv --match-path "./test/e2e/**" --force

# Full coverage with HTML report
generate-coverage:
	rm -rf coverage lcov.info && \
	FOUNDRY_PROFILE=test forge coverage \
		--ir-minimum \
		--report lcov \
		--no-match-coverage "script|src/mocks|src/interfaces|test"
	@if [ "$$CI" != "true" ]; then \
		genhtml lcov.info --branch-coverage --output-dir coverage; \
	fi

clean:
	forge clean

#
# High-level deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(ANVIL_SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL) \

deploy-on-mainnets:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=ethereum SOURCE_RPC=$(ETHEREUM_RPC_URL) \
		TARGET_CHAIN=arbitrum TARGET_RPC=$(ARBITRUM_RPC_URL) \

deploy-on-testnets:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \

deploy-liquidity-unifier-and-bridge:
	$(MAKE) deploy-contract CONTRACT=RLCLiquidityUnifier CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

deploy-crosschain-token-and-bridge:
	$(MAKE) deploy-contract CONTRACT=RLCCrosschainToken CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

deploy-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC
	$(MAKE) deploy-liquidity-unifier-and-bridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC)
	$(MAKE) deploy-crosschain-token-and-bridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC)
	@echo "Contracts deployment completed."
	@echo "⚠️ Run 'make configure-all' to configure bridges."
	@echo "⚠️ Please configure the bridges. Do not forget to authorize the RLCLiquidityUnifier and RLCCrosschainToken contracts on the bridges."

configure-all: # SOURCE_CHAIN, TARGET_CHAIN, SOURCE_RPC, TARGET_RPC
	$(MAKE) configure-bridge SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) RPC_URL=$(SOURCE_RPC)
	$(MAKE) configure-bridge SOURCE_CHAIN=$(TARGET_CHAIN) TARGET_CHAIN=$(SOURCE_CHAIN) RPC_URL=$(TARGET_RPC)
	@echo "Bridge configuration completed."

#
# High-level upgrade targets
#

upgrade-on-anvil:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(ANVIL_SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-mainnets:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=ethereum SOURCE_RPC=$(ETHEREUM_RPC_URL) \
		TARGET_CHAIN=arbitrum TARGET_RPC=$(ARBITRUM_RPC_URL) \

# TODO : RLCMultichain and RLCLiquidityUnifier upgrades
upgrade-on-testnets:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \

upgrade-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC)
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC)

#
# Generic deployment targets
#

deploy-contract: # CONTRACT, CHAIN, RPC_URL
	@echo "Deploying $(CONTRACT) on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(DEPLOYER_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv

#
# Generic upgrade targets
#

upgrade-contract: # CONTRACT, CHAIN, RPC_URL
	@echo "Upgrading $(CONTRACT) on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Upgrade \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

#
# Generic configuration targets
#

configure-bridge: # SOURCE_CHAIN, TARGET_CHAIN, RPC_URL
	@echo "Configuring LayerZero Bridge $(SOURCE_CHAIN) -> $(TARGET_CHAIN)"
	SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) \
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(ADMIN_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv

#
# Individual upgrade targets
#

upgrade-layerzero-bridge: # CHAIN, RPC_URL
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

#
# Bridge operations.
#

# Testnet bridge operations

send-tokens-to-arbitrum-sepolia:
	@echo "Sending tokens cross-chain... from SEPOLIA to Arbitrum SEPOLIA"
	SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia \
	forge script script/SendFromEthereumToArbitrum.s.sol:SendFromEthereumToArbitrum \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

send-tokens-to-sepolia:
	@echo "Sending tokens cross-chain... from Arbitrum SEPOLIA to SEPOLIA"
	SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia \
	forge script script/SendFromArbitrumToEthereum.s.sol:SendFromArbitrumToEthereum \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

# Mainnet bridge operations
send-tokens-to-arbitrum-mainnet:
	@echo "Sending tokens cross-chain... from ETHEREUM to Arbitrum MAINNET"
	SOURCE_CHAIN=ethereum TARGET_CHAIN=arbitrum \
	forge script script/SendFromEthereumToArbitrum.s.sol:SendFromEthereumToArbitrum \
		--rpc-url $(ETHEREUM_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

send-tokens-to-ethereum-mainnet:
	@echo "Sending tokens cross-chain... from Arbitrum MAINNET to ETHEREUM"
	SOURCE_CHAIN=arbitrum TARGET_CHAIN=ethereum \
	forge script script/SendFromArbitrumToEthereum.s.sol:SendFromArbitrumToEthereum \
		--rpc-url $(ARBITRUM_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

#
# Admin role transfer operations
#

# Transfer admin role for a single chain
begin-default-admin-transfer: # CHAIN, RPC_URL, NEW_DEFAULT_ADMIN
	@echo "Transferring admin role on $(CHAIN) to: $(NEW_DEFAULT_ADMIN)"
	CHAIN=$(CHAIN) NEW_DEFAULT_ADMIN=$(NEW_DEFAULT_ADMIN) forge script script/TransferAdminRole.s.sol:BeginTransferAdminRole \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(ADMIN_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv

# Accept admin role for a single chain (run by new admin)
accept-default-admin-transfer: # CHAIN, RPC_URL
	@echo "Accepting admin role on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/TransferAdminRole.s.sol:AcceptAdminRole \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(NEW_DEFAULT_ADMIN_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv
