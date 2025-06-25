# ===============================================
# IEXEC verification COMMANDS
# ===============================================

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
