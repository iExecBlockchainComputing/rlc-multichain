
# ========================================================================
# 						VERIFICATION TARGETS
# ========================================================================

# ========================================================================
#							PROXY VERIFICATION 
# ========================================================================
verify-rlc-liquidity-unifier-proxy-sepolia:
	@echo "Verifying RLCLiquidityUnifier Proxy on Sepolia Etherscan..."
	@echo "Using address from config.json: $(shell ./scripts/get_config_address.sh sepolia rlcLiquidityUnifierAddress)"
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(shell ./scripts/get_config_address.sh sepolia rlcLiquidityUnifierAddress) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-layerzero-bridge-proxy-sepolia:
	@echo "Verifying IexecLayerZeroBridge Proxy on Sepolia Etherscan..."
	@echo "Using address from config.json: $(shell ./scripts/get_config_address.sh sepolia iexecLayerZeroBridgeAddress)"
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(shell ./scripts/get_config_address.sh sepolia iexecLayerZeroBridgeAddress) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-rlc-crosschain-token-proxy-arbitrum-sepolia:
	@echo "Verifying RLCCrosschainToken Proxy on Arbitrum Sepolia..."
	@echo "Using address from config.json: $(shell ./scripts/get_config_address.sh arbitrum_sepolia rlcCrosschainTokenAddress)"
	forge verify-contract \
		--chain-id 421614 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(shell ./scripts/get_config_address.sh arbitrum_sepolia rlcCrosschainTokenAddress) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-layerzero-bridge-proxy-arbitrum-sepolia:
	@echo "Verifying IexecLayerZeroBridge Proxy on Arbitrum Sepolia..."
	@echo "Using address from config.json: $(shell ./scripts/get_config_address.sh arbitrum_sepolia iexecLayerZeroBridgeAddress)"
	forge verify-contract \
		--chain-id 421614 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(shell ./scripts/get_config_address.sh arbitrum_sepolia iexecLayerZeroBridgeAddress) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

# ========================================================================
#							IMPLEMENTATION VERIFICATION
# ========================================================================
verify-rlc-liquidity-unifier-impl-sepolia:
	@echo "Verifying RLCLiquidityUnifier Implementation on Sepolia Etherscan..."
	@echo "Getting implementation address from proxy..."
	$(eval PROXY_ADDRESS := $(shell ./scripts/get_config_address.sh sepolia rlcLiquidityUnifierAddress))
	$(eval IMPL_ADDRESS := $(shell ./scripts/get_implementation_address.sh $(PROXY_ADDRESS) $(SEPOLIA_RPC_URL) | tail -n 1))
	@echo "Proxy address: $(PROXY_ADDRESS)"
	@echo "Implementation address: $(IMPL_ADDRESS)"
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address)" $(shell ./scripts/get_config_address.sh sepolia rlcAddress)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(IMPL_ADDRESS) \
		src/RLCLiquidityUnifier.sol:RLCLiquidityUnifier

verify-layerzero-bridge-impl-sepolia:
	@echo "Verifying IexecLayerZeroBridge Implementation on Sepolia Etherscan..."
	@echo "Getting implementation address from proxy..."
	$(eval PROXY_ADDRESS := $(shell ./scripts/get_config_address.sh sepolia iexecLayerZeroBridgeAddress))
	$(eval IMPL_ADDRESS := $(shell ./scripts/get_implementation_address.sh $(PROXY_ADDRESS) $(SEPOLIA_RPC_URL) | tail -n 1))
	@echo "Proxy address: $(PROXY_ADDRESS)"
	@echo "Implementation address: $(IMPL_ADDRESS)"
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(bool,address,address)" true $(shell ./scripts/get_config_address.sh sepolia rlcLiquidityUnifierAddress) $(shell ./scripts/get_config_address.sh sepolia lzEndpointAddress)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(IMPL_ADDRESS) \
		src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

verify-rlc-crosschain-token-impl-arbitrum-sepolia:
	@echo "Verifying RLCCrosschainToken Implementation on Arbitrum Sepolia..."
	@echo "Getting implementation address from proxy..."
	$(eval PROXY_ADDRESS := $(shell ./scripts/get_config_address.sh arbitrum_sepolia rlcCrosschainTokenAddress))
	$(eval IMPL_ADDRESS := $(shell ./scripts/get_implementation_address.sh $(PROXY_ADDRESS) $(ARBITRUM_SEPOLIA_RPC_URL) | tail -n 1))
	@echo "Proxy address: $(PROXY_ADDRESS)"
	@echo "Implementation address: $(IMPL_ADDRESS)"
	forge verify-contract \
		--chain-id 421614 \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(IMPL_ADDRESS) \
		src/RLCCrosschainToken.sol:RLCCrosschainToken

verify-layerzero-bridge-impl-arbitrum-sepolia:
	@echo "Verifying IexecLayerZeroBridge Implementation on Arbitrum Sepolia..."
	@echo "Getting implementation address from proxy..."
	$(eval PROXY_ADDRESS := $(shell ./scripts/get_config_address.sh arbitrum_sepolia iexecLayerZeroBridgeAddress))
	$(eval IMPL_ADDRESS := $(shell ./scripts/get_implementation_address.sh $(PROXY_ADDRESS) $(ARBITRUM_SEPOLIA_RPC_URL) | tail -n 1))
	@echo "Proxy address: $(PROXY_ADDRESS)"
	@echo "Implementation address: $(IMPL_ADDRESS)"
	forge verify-contract \
		--chain-id 421614 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(bool,address,address)" false $(shell ./scripts/get_config_address.sh arbitrum_sepolia rlcCrosschainTokenAddress) $(shell ./scripts/get_config_address.sh arbitrum_sepolia lzEndpointAddress)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(IMPL_ADDRESS) \
		src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge

# ========================================================================
#							PROXY AND IMPLEMENTATION VERIFICATION
# ========================================================================
verify-proxies-sepolia: verify-rlc-liquidity-unifier-proxy-sepolia verify-layerzero-bridge-proxy-sepolia
verify-proxies-arbitrum-sepolia: verify-rlc-crosschain-token-proxy-arbitrum-sepolia verify-layerzero-bridge-proxy-arbitrum-sepolia
verify-proxies-testnets: verify-proxies-sepolia verify-proxies-arbitrum-sepolia

verify-implementations-sepolia: verify-rlc-liquidity-unifier-impl-sepolia verify-layerzero-bridge-impl-sepolia
verify-implementations-arbitrum-sepolia: verify-rlc-crosschain-token-impl-arbitrum-sepolia verify-layerzero-bridge-impl-arbitrum-sepolia
verify-implementations-testnets: verify-implementations-sepolia verify-implementations-arbitrum-sepolia

verify-sepolia: verify-proxies-sepolia
verify-arbitrum-sepolia: verify-proxies-arbitrum-sepolia
verify-testnets: verify-proxies-testnets

# ========================================================================
#							COMPLETION TARGETS
# ========================================================================

verify-all-sepolia: verify-proxies-sepolia verify-implementations-sepolia
verify-all-arbitrum-sepolia: verify-proxies-arbitrum-sepolia verify-implementations-arbitrum-sepolia
verify-all-testnets: verify-all-sepolia verify-all-arbitrum-sepolia
