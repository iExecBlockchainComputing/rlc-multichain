MAKEFLAGS += --no-print-directory

include report.mk
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

cleanup-anvil:
	@echo "Stopping all anvil processes..."
	@-pkill -f "anvil.*port" 2>/dev/null || echo "No anvil processes found to stop"
	@sleep 2
	@echo "Anvil cleanup completed."

#
# High-level deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(ANVIL_SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL) \
		OPTIONS=

deploy-on-mainnets:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=ethereum SOURCE_RPC=$(ETHEREUM_RPC_URL) \
		TARGET_CHAIN=arbitrum TARGET_RPC=$(ARBITRUM_RPC_URL) \
		OPTIONS=--verify

deploy-on-testnets:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \
		OPTIONS="--verify --verifier etherscan --verifier-api-key $(ETHERSCAN_API_KEY) --verifier-url $(ETHERSCAN_API_URL)"

deploy-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC, OPTIONS
	$(MAKE) deploy-contract CONTRACT=RLCLiquidityUnifier CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) OPTIONS="$(OPTIONS)"
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) OPTIONS="$(OPTIONS)"
	$(MAKE) deploy-contract CONTRACT=RLCCrosschainToken CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) OPTIONS="$(OPTIONS)"
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) OPTIONS="$(OPTIONS)"
	$(MAKE) configure-bridge SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) RPC_URL=$(SOURCE_RPC)
	$(MAKE) configure-bridge SOURCE_CHAIN=$(TARGET_CHAIN) TARGET_CHAIN=$(SOURCE_CHAIN) RPC_URL=$(TARGET_RPC)
	@echo "Deployment completed."
	@echo "⚠️ Please authorize bridges on RLCLiquidityUnifier and RLCCrosschainToken contracts."
	# TODO verify contracts after deployment.

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
		OPTIONS=--verify

# TODO : RLCMultichain and RLCLiquidityUnifier upgrades
upgrade-on-testnets:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \
		OPTIONS=--verify

upgrade-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC, OPTIONS
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) OPTIONS=$(OPTIONS)
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) OPTIONS=$(OPTIONS)

#
# Generic deployment targets
#

deploy-contract: # CONTRACT, CHAIN, RPC_URL, OPTIONS
	@echo "Deploying $(CONTRACT) on $(CHAIN) with options: $(OPTIONS)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		$(OPTIONS) \
		--broadcast \
		-vvv

#
# Generic upgrade targets
#

upgrade-contract: # CONTRACT, CHAIN, RPC_URL, OPTIONS
	@echo "Upgrading $(CONTRACT) on $(CHAIN) with options: $(OPTIONS)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Upgrade \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		$(OPTIONS) \
		-vvv

#
# Generic configuration targets
#

configure-bridge: # SOURCE_CHAIN, TARGET_CHAIN, RPC_URL
	@echo "Configuring LayerZero Bridge $(SOURCE_CHAIN) -> $(TARGET_CHAIN)"
	SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) \
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
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

send-tokens-to-arbitrum-sepolia:
	@echo "Sending tokens cross-chain... from SEPOLIA to Arbitrum SEPOLIA"
	SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia \
	forge script script/SendFromEthereumToArbitrum.s.sol:SendTokensFromEthereumToArbitrum \
		--rpc-url $(SEPOLIA_RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv

send-tokens-to-sepolia:
	@echo "Sending tokens cross-chain... from Arbitrum SEPOLIA to SEPOLIA"
	SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia \
	forge script script/SendFromArbitrumToEthereum.s.sol:SendTokensFromArbitrumToEthereum \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv
