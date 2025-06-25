
MAKEFLAGS += --no-print-directory

include report.mk verification.mk
-include .env


#
# Test and utility targets
#

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
		--no-match-coverage "script|src/mocks|test"
	@if [ "$$CI" != "true" ]; then \
		genhtml lcov.info --branch-coverage --output-dir coverage; \
	fi

clean:
	forge clean

#
# Deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-liquidity-unifier CHAIN=sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge CHAIN=sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-rlc-crosschain-token CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-layerzero-bridge CHAIN=sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layer2-LZ-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-layerzero-bridge CHAIN=sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-layerzero-bridge CHAIN=sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layerzero-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

# Generic deployment targets (works with any chain)
deploy-liquidity-unifier:
	@echo "Deploying RLCLiquidityUnifier (UUPS Proxy) on $(CHAIN): $(RPC_URL)"
	CHAIN=$(CHAIN) forge script script/RLCLiquidityUnifier.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

deploy-rlc-crosschain-token:
	@echo "Deploying RLC cross-chain token (UUPS Proxy) on $(CHAIN): $(RPC_URL)"
	CHAIN=$(CHAIN) forge script script/RLCCrosschainToken.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

deploy-layerzero-bridge:
	@echo "Deploying IexecLayerZeroBridge (UUPS Proxy) on $(CHAIN): $(RPC_URL)"
	CHAIN=$(CHAIN) forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

configure-layerzero-bridge:
	@echo "Configuring IexecLayerZeroBridge $(SOURCE_CHAIN) -> $(TARGET_CHAIN): $(RPC_URL)"
	SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) \
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

#
# Upgrade targets
#

validate-layerzero-bridge:
	@echo "Validating IexecLayerZeroBridge upgrade on $(CHAIN): $(RPC_URL)"
	CHAIN=$(CHAIN) forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

upgrade-layerzero-bridge:
	@echo "Upgrading IexecLayerZeroBridge on $(CHAIN): $(RPC_URL)"
	$(MAKE) validate-layerzero-bridge
	CHAIN=$(CHAIN) forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Upgrade \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

#
# Bridge operations.
#

send-tokens-to-arbitrum-sepolia:
	@echo "Sending tokens cross-chain... from SEPOLIA to Arbitrum SEPOLIA"
	forge script script/SendEthereumToArbitrum.s.sol:SendTokensToArbitrumSepolia \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

send-tokens-to-sepolia:
	@echo "Sending tokens cross-chain... from Arbitrum SEPOLIA to SEPOLIA"
	forge script script/SendArbitrumToEthereum.s.sol:SendTokensToSepolia \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv
