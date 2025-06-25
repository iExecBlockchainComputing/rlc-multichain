
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
	$(MAKE) deploy-layerzero-bridge CHAIN=sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-rlc-crosschain-token CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-layer1-LZ-bridge CHAIN=sepolia RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layer2-LZ-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-layerzero-bridge CHAIN=sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=sepolia TARGET_CHAIN=arbitrum_sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge SOURCE_CHAIN=arbitrum_sepolia TARGET_CHAIN=sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-layer1-LZ-bridge CHAIN=sepolia RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layer2-LZ-bridge CHAIN=arbitrum_sepolia RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

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

#
# Verification targets
#

#
# Implementation verification
#

verify-layerzero-bridge-impl:
	@echo "Verifying IexecLayerZeroBridge Implementation on $(CHAIN_NAME)..."
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address,address)" $(BRIDGEABLE_TOKEN_ADDRESS) $(LAYER_ZERO_ENDPOINT_ADDRESS)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) \
		src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

#
# Proxy verification  
#

verify-layerzero-bridge-proxy:
	@echo "Verifying IexecLayerZeroBridge Proxy on $(CHAIN_NAME)..."
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address,address)" $(INITIAL_ADMIN_ADDRESS) $(INITIAL_UPGRADER_ADDRESS) $(INITIAL_PAUSER_ADDRESS))) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(LAYERZERO_BRIDGE_PROXY_ADDRESS) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

#
# Chain-specific verification targets
#

# Sepolia verification
verify-sepolia-layerzero-bridge-impl:
	$(MAKE) verify-layerzero-bridge-impl \
		CHAIN_NAME="Sepolia" \
		CHAIN_ID=11155111 \
		BRIDGEABLE_TOKEN_ADDRESS=$(RLC_ADDRESS) \
		LAYER_ZERO_ENDPOINT_ADDRESS=$(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS) \
		ETHERSCAN_API_KEY=$(ETHERSCAN_API_KEY) \
		LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS=$(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS)

verify-sepolia-layerzero-bridge-proxy:
	$(MAKE) verify-layerzero-bridge-proxy \
		CHAIN_NAME="Sepolia" \
		CHAIN_ID=11155111 \
		ETHERSCAN_API_KEY=$(ETHERSCAN_API_KEY) \
		LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS=$(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) \
		LAYERZERO_BRIDGE_PROXY_ADDRESS=$(LAYERZERO_BRIDGE_PROXY_ADDRESS) \
		INITIAL_ADMIN_ADDRESS=$(INITIAL_ADMIN_ADDRESS) \
		INITIAL_UPGRADER_ADDRESS=$(INITIAL_UPGRADER_ADDRESS) \
		INITIAL_PAUSER_ADDRESS=$(INITIAL_PAUSER_ADDRESS)

# Arbitrum Sepolia verification
verify-arbitrum-sepolia-layerzero-bridge-impl:
	$(MAKE) verify-layerzero-bridge-impl \
		CHAIN_NAME="Arbitrum Sepolia" \
		CHAIN_ID=421614 \
		BRIDGEABLE_TOKEN_ADDRESS=$(RLC_CROSSCHAIN_TOKEN_ADDRESS) \
		LAYER_ZERO_ENDPOINT_ADDRESS=$(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS) \
		ETHERSCAN_API_KEY=$(ARBISCAN_API_KEY) \
		LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS=$(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS)

verify-arbitrum-sepolia-layerzero-bridge-proxy:
	$(MAKE) verify-layerzero-bridge-proxy \
		CHAIN_NAME="Arbitrum Sepolia" \
		CHAIN_ID=421614 \
		ETHERSCAN_API_KEY=$(ARBISCAN_API_KEY) \
		LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS=$(LAYERZERO_BRIDGE_IMPLEMENTATION_ADDRESS) \
		LAYERZERO_BRIDGE_PROXY_ADDRESS=$(LAYERZERO_BRIDGE_PROXY_ADDRESS) \
		INITIAL_ADMIN_ADDRESS=$(INITIAL_ADMIN_ADDRESS) \
		INITIAL_UPGRADER_ADDRESS=$(INITIAL_UPGRADER_ADDRESS) \
		INITIAL_PAUSER_ADDRESS=$(INITIAL_PAUSER_ADDRESS)

#
# RLC Liquidity Unifier verification (Sepolia)
#

verify-sepolia-rlc-liquidity-unifier-impl:
	@echo "Verifying RLC Liquidity Unifier Implementation on Sepolia..."
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(RLC_LIQUIDITY_UNIFIER_IMPLEMENTATION_ADDRESS) \
		src/RLCLiquidityUnifier.sol:RLCLiquidityUnifier

verify-sepolia-rlc-liquidity-unifier-proxy:
	@echo "Verifying RLC Liquidity Unifier Proxy on Sepolia..."
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_LIQUIDITY_UNIFIER_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address,address)" $(INITIAL_ADMIN_ADDRESS) $(INITIAL_UPGRADER_ADDRESS) $(INITIAL_PAUSER_ADDRESS))) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(RLC_LIQUIDITY_UNIFIER_PROXY_ADDRESS) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

#
# RLC Crosschain Token verification
#

verify-rlc-crosschain-token-impl:
	@echo "Verifying RLC Crosschain Token Implementation on $(CHAIN_NAME)..."
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS) \
		src/RLCCrosschainToken.sol:RLCCrosschainToken

verify-rlc-crosschain-token-proxy:
	@echo "Verifying RLC Crosschain Token Proxy on $(CHAIN_NAME)..."
	forge verify-contract \
		--chain-id $(CHAIN_ID) \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address,address)" $(INITIAL_ADMIN_ADDRESS) $(INITIAL_UPGRADER_ADDRESS) $(INITIAL_PAUSER_ADDRESS))) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(RLC_CROSSCHAIN_TOKEN_PROXY_ADDRESS) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
#
# Chain-specific RLC Crosschain Token verification targets
#

# Arbitrum Sepolia verification
verify-arbitrum-sepolia-rlc-crosschain-token-impl:
	$(MAKE) verify-rlc-crosschain-token-impl \
		CHAIN_NAME="Arbitrum Sepolia" \
		CHAIN_ID=421614 \
		ETHERSCAN_API_KEY=$(ARBISCAN_API_KEY) \
		RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS=$(RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS)

verify-arbitrum-sepolia-rlc-crosschain-token-proxy:
	$(MAKE) verify-rlc-crosschain-token-proxy \
		CHAIN_NAME="Arbitrum Sepolia" \
		CHAIN_ID=421614 \
		ETHERSCAN_API_KEY=$(ARBISCAN_API_KEY) \
		RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS=$(RLC_CROSSCHAIN_TOKEN_IMPLEMENTATION_ADDRESS) \
		RLC_CROSSCHAIN_TOKEN_PROXY_ADDRESS=$(RLC_CROSSCHAIN_TOKEN_PROXY_ADDRESS) \
		INITIAL_ADMIN_ADDRESS=$(INITIAL_ADMIN_ADDRESS) \
		INITIAL_UPGRADER_ADDRESS=$(INITIAL_UPGRADER_ADDRESS) \
		INITIAL_PAUSER_ADDRESS=$(INITIAL_PAUSER_ADDRESS)

#
# Complete contract verification targets
#

# LayerZero Bridge complete verification
verify-sepolia-layerzero-bridge: verify-sepolia-layerzero-bridge-impl verify-sepolia-layerzero-bridge-proxy
verify-arbitrum-sepolia-layerzero-bridge: verify-arbitrum-sepolia-layerzero-bridge-impl verify-arbitrum-sepolia-layerzero-bridge-proxy

# RLC Crosschain Token complete verification
verify-arbitrum-sepolia-rlc-crosschain-token: verify-arbitrum-sepolia-rlc-crosschain-token-impl verify-arbitrum-sepolia-rlc-crosschain-token-proxy

# RLC Liquidity Unifier complete verification
verify-sepolia-rlc-liquidity-unifier: verify-sepolia-rlc-liquidity-unifier-impl verify-sepolia-rlc-liquidity-unifier-proxy

#
# Chain complete verification targets
#

# Sepolia complete (LayerZero Bridge + RLC Liquidity Unifier)
verify-sepolia-complete: verify-sepolia-layerzero-bridge verify-sepolia-rlc-liquidity-unifier

# Arbitrum Sepolia complete (LayerZero Bridge + RLC Crosschain Token)
verify-arbitrum-sepolia-complete: verify-arbitrum-sepolia-layerzero-bridge verify-arbitrum-sepolia-rlc-crosschain-token
