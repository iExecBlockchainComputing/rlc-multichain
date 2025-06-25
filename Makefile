# Makefile for RLC OFT Project

MAKEFLAGS += --no-print-directory

include report.mk
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
	$(MAKE) deploy-layer1-LZ-bridge RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-rlc-crosschain-token RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layer2-LZ-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layer1-LZ-bridge RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-layer2-LZ-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-layer1-LZ-bridge RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layer2-LZ-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-layer1-LZ-bridge RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-layer2-LZ-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layer1-LZ-bridge RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-layer2-LZ-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-layer1-LZ-bridge RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layer2-LZ-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

deploy-liquidity-unifier:
	@echo "Deploying LiquidityUnifier (UUPS Proxy) on: $(RPC_URL)"
	CHAIN=sepolia forge script script/LiquidityUnifier.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

deploy-layer1-LZ-bridge:
	@echo "Deploying Layer 1 LZ Bridge (UUPS Proxy) on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

# deploy-rlc-crosschain-token RPC_URL=https://...
deploy-rlc-crosschain-token:
	@echo "Deploying RLC cross-chain token (UUPS Proxy) on : $(RPC_URL)"
	CHAIN=arbitrum_sepolia forge script script/RLCCrosschainToken.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

deploy-layer2-LZ-bridge:
	@echo "Deploying Layer 2 LZ Bridge (UUPS Proxy) on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-layer1-LZ-bridge:
	@echo "Configuring Layer 1 LZ Bridge on: $(RPC_URL)..."
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-layer2-LZ-bridge:
	@echo "Configuring Layer 2 LZ Bridge on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

#
# Upgrade targets
#

validate-layer1-LZ-bridge-upgrade:
	@echo "Validating Layer 1 LZ Bridge upgrade on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

validate-layer2-LZ-bridge-upgrade:
	@echo "Validating Layer 2 LZ Bridge upgrade on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

upgrade-layer1-LZ-bridge:
	@echo "Upgrading Layer 1 LZ Bridge on: $(RPC_URL)"
	$(MAKE) validate-layer1-LZ-bridge-upgrade
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Upgrade \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

upgrade-layer2-LZ-bridge:
	@echo "Upgrading Layer 2 LZ Bridge on: $(RPC_URL)"
	$(MAKE) validate-layer2-LZ-bridge-upgrade
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Upgrade \
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

#
# Verification targets
#

# Implementation verification
verify-layer1-LZ-bridge-impl:
	@echo "Verifying Layer 1 LZ Bridge Implementation on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,address)" $(RLC_ADDRESS) $(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) \
        src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

verify-layer2-LZ-bridge-impl:
	@echo "Verifying Layer 2 LZ Bridge Implementation on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address)" $(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) \
        src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

# Proxy verification
verify-adapter-proxy:
	@echo "Verifying Layer 1 LZ Bridge Proxy on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_ADAPTER_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-layerzero-bridge-proxy:
	@echo "Verifying Layer 2 LZ Bridge Proxy on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(LAYERZERO_BRIDGE_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

# Combined verification targets
verify-adapter: verify-layer1-LZ-bridge-impl verify-adapter-proxy
verify-layerzero-bridge: verify-layerzero-bridge-impl verify-layerzero-bridge-proxy

verify-implementations: verify-layer1-LZ-bridge-impl verify-layerzero-bridge-impl
verify-proxies: verify-adapter-proxy verify-layerzero-bridge-proxy
verify-all: verify-implementations verify-proxies
