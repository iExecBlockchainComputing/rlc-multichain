# Makefile for RLC OFT Project

MAKEFLAGS += --no-print-directory

-include .env

generate-coverage:
	rm -rf coverage lcov.info lcov.src.info && \
	forge coverage \
		--ir-minimum \
		--report lcov \
		--no-match-coverage "script|src/mocks|test" && \
	genhtml lcov.info --branch-coverage --output-dir coverage

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

clean:
	forge clean

#
# Deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-rlc-crosschain-token RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

deploy-adapter:
	@echo "Deploying RLCAdapter (UUPS Proxy) on: $(RPC_URL)"
	forge script script/bridges/layerZero/RLCAdapter.s.sol:Deploy \
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

deploy-layerzero-bridge:
	@echo "Deploying IexecLayerZeroBridge (UUPS Proxy) on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-adapter:
	@echo "Configuring RLCAdapter on: $(RPC_URL)..."
	forge script script/bridges/layerZero/RLCAdapter.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-layerzero-bridge:
	@echo "Configuring RLCOFT on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

#
# Upgrade targets
#

validate-adapter-upgrade:
	@echo "Validating RLCAdapter upgrade on: $(RPC_URL)"
	forge script script/bridges/layerZero/RLCAdapter.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

validate-layerZero-bridge-upgrade:
	@echo "Validating RLC LayerZero upgrade on: $(RPC_URL)"
	forge script script/bridges/layerZero/IexecLayerZeroBridge.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

upgrade-adapter:
	@echo "Upgrading RLCAdapter on: $(RPC_URL)"
	$(MAKE) validate-adapter-upgrade
	forge script script/bridges/layerZero/RLCAdapter.s.sol:Upgrade \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

upgrade-layerzero-bridge:
	@echo "Upgrading RLC LayerZero Bridge on: $(RPC_URL)"
	$(MAKE) validate-layerZero-bridge-upgrade
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
verify-adapter-impl:
	@echo "Verifying RLCAdapter Implementation on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,address)" $(RLC_ADDRESS) $(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) \
        src/bridges/layerZero/RLCAdapter.sol:RLCAdapter

verify-layerzero-bridge-impl:
	@echo "Verifying RLCOFT Implementation on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address)" $(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) \
        src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

# Proxy verification
verify-adapter-proxy:
	@echo "Verifying RLCAdapter Proxy on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_ADAPTER_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-layerzero-bridge-proxy:
	@echo "Verifying RLCOFT Proxy on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(LAYERZERO_BRIDGE_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

# Combined verification targets
verify-adapter: verify-adapter-impl verify-adapter-proxy
verify-layerzero-bridge: verify-layerzero-bridge-impl verify-layerzero-bridge-proxy

verify-implementations: verify-adapter-impl verify-layerzero-bridge-impl
verify-proxies: verify-adapter-proxy verify-layerzero-bridge-proxy
verify-all: verify-implementations verify-proxies
