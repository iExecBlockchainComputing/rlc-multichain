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
# High-level deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(ANVIL_SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL) \
		ENABLE_VERIFICATION=false

deploy-on-testnets:
	$(MAKE) deploy-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \
		ENABLE_VERIFICATION=true

deploy-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC, [ENABLE_VERIFICATION]
	$(MAKE) deploy-contract CONTRACT=RLCLiquidityUnifier CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)
	$(MAKE) deploy-contract CONTRACT=RLCCrosschainToken CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)
	$(MAKE) configure-bridge SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) RPC_URL=$(SOURCE_RPC)
	$(MAKE) configure-bridge SOURCE_CHAIN=$(TARGET_CHAIN) TARGET_CHAIN=$(SOURCE_CHAIN) RPC_URL=$(TARGET_RPC)

#
# High-level upgrade targets
#

upgrade-on-anvil:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(ANVIL_SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-all \
		SOURCE_CHAIN=sepolia SOURCE_RPC=$(SEPOLIA_RPC_URL) \
		TARGET_CHAIN=arbitrum_sepolia TARGET_RPC=$(ARBITRUM_SEPOLIA_RPC_URL) \
		ENABLE_VERIFICATION=true

upgrade-all: # SOURCE_CHAIN, SOURCE_RPC, TARGET_CHAIN, TARGET_RPC, [ENABLE_VERIFICATION]
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(SOURCE_CHAIN) RPC_URL=$(SOURCE_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(TARGET_CHAIN) RPC_URL=$(TARGET_RPC) $(if $(filter true,$(ENABLE_VERIFICATION)),ENABLE_VERIFICATION=true,)

#
# Generic deployment targets
#

deploy-contract: # CONTRACT, CHAIN, RPC_URL, [ENABLE_VERIFICATION]
	@echo "Deploying $(CONTRACT) on $(CHAIN)$(if $(filter true,$(ENABLE_VERIFICATION)), with verification,)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		$(if $(filter true,$(ENABLE_VERIFICATION)),--verify,) \
		--broadcast \
		-vvv

#
# Generic upgrade targets
#

validate-contract: # CONTRACT, CHAIN, RPC_URL
	@echo "Validating $(CONTRACT) upgrade on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:ValidateUpgrade \
		--rpc-url $(RPC_URL) \
		-vvv

upgrade-contract: # CONTRACT, CHAIN, RPC_URL, [ENABLE_VERIFICATION]
	@echo "Upgrading $(CONTRACT) on $(CHAIN)$(if $(filter true,$(ENABLE_VERIFICATION)), with verification,)"
	$(MAKE) validate-contract CONTRACT=$(CONTRACT) CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)
	CHAIN=$(CHAIN) forge script script/$(CONTRACT).s.sol:Upgrade \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		$(if $(filter true,$(ENABLE_VERIFICATION)),--verify,) \
		-vvv

#
# Generic configuration targets
#

configure-bridge: # SOURCE_CHAIN, TARGET_CHAIN, RPC_URL
	@echo "Configuring LayerZero Bridge $(SOURCE_CHAIN) -> $(TARGET_CHAIN)"
	SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) \
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

#
# Individual deployment targets
#

deploy-liquidity-unifier: # CHAIN, RPC_URL
	$(MAKE) deploy-contract CONTRACT=RLCLiquidityUnifier CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

deploy-rlc-crosschain-token: # CHAIN, RPC_URL
	$(MAKE) deploy-contract CONTRACT=RLCCrosschainToken CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

deploy-layerzero-bridge: # CHAIN, RPC_URL
	$(MAKE) deploy-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

configure-layerzero-bridge: # SOURCE_CHAIN, TARGET_CHAIN, RPC_URL
	$(MAKE) configure-bridge SOURCE_CHAIN=$(SOURCE_CHAIN) TARGET_CHAIN=$(TARGET_CHAIN) RPC_URL=$(RPC_URL)

#
# Individual upgrade targets 
#

validate-layerzero-bridge: # CHAIN, RPC_URL
	$(MAKE) validate-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

upgrade-layerzero-bridge: # CHAIN, RPC_URL
	$(MAKE) upgrade-contract CONTRACT=bridges/layerZero/IexecLayerZeroBridge CHAIN=$(CHAIN) RPC_URL=$(RPC_URL)

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
