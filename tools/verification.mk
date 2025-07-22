
# ========================================================================
#                          SMART CONTRACT VERIFICATION
# ========================================================================
# Chain IDs for supported networks
SEPOLIA_CHAIN_ID := 11155111
ARBITRUM_SEPOLIA_CHAIN_ID := 421614

# ========================================================================
#                          VERIFICATION FUNCTIONS
# ========================================================================

# Verify ERC1967 proxy contracts
# Parameters: CONTRACT_NAME, NETWORK, CONFIG_KEY, CHAIN_ID, DISPLAY_NAME
define verify-proxy
	@echo "Verifying $(1) Proxy on $(5)..."
	forge verify-contract \
		--chain-id $(4) \
		--watch \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" $(2) $(3) 2>/dev/null | grep "0x" | tail -n1) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
	@echo "Proxy verification completed for $(1) on $(5)"
endef

# Verify implementation contracts with optional constructor arguments
# Parameters: CONTRACT_NAME, NETWORK, CONFIG_KEY, CHAIN_ID, DISPLAY_NAME, CONTRACT_PATH, RPC_URL, CONSTRUCTOR_ARGS
define verify-impl
	@echo "Verifying $(1) Implementation on $(5)..."
	@proxy_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" $(2) $(3) 2>/dev/null | grep "0x" | tail -n1); \
	impl_address=$$(forge script script/GetConfigInfo.s.sol --sig "getImplementationAddress(string,string)" $(2) $(3) --rpc-url $(7) 2>/dev/null | grep "0x" | tail -n1); \
	echo "Proxy address: $$proxy_address"; \
	echo "Implementation address: $$impl_address"; \
	forge verify-contract \
		--chain-id $(4) \
		--watch \
		$(8) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$$impl_address \
		$(6); \
	echo "Implementation verification completed for $(1) on $(5)"; \
	echo ""
endef

# ========================================================================
#                          SEPOLIA NETWORK VERIFICATION
# ========================================================================

# Proxy Verifications - Sepolia
# -----------------------------
verify-rlc-liquidity-unifier-proxy-sepolia:
	$(call verify-proxy,RLCLiquidityUnifier,sepolia,rlcLiquidityUnifierAddress,$(SEPOLIA_CHAIN_ID),Sepolia Etherscan)

verify-layerzero-bridge-proxy-sepolia:
	$(call verify-proxy,IexecLayerZeroBridge,sepolia,iexecLayerZeroBridgeAddress,$(SEPOLIA_CHAIN_ID),Sepolia Etherscan)

# Implementation Verifications - Sepolia
# --------------------------------------
verify-rlc-liquidity-unifier-impl-sepolia:
	@rlc_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" sepolia rlcToken 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$(cast abi-encode "constructor(address)" $$rlc_address); \
	$(MAKE) _verify-rlc-liquidity-unifier-impl-sepolia CONSTRUCTOR_ARGS="--constructor-args $$constructor_args"

_verify-rlc-liquidity-unifier-impl-sepolia:
	$(call verify-impl,RLCLiquidityUnifier,sepolia,rlcLiquidityUnifierAddress,$(SEPOLIA_CHAIN_ID),Sepolia Etherscan,src/RLCLiquidityUnifier.sol:RLCLiquidityUnifier,$(SEPOLIA_RPC_URL),$(CONSTRUCTOR_ARGS))

verify-layerzero-bridge-impl-sepolia:
	@echo "Building constructor arguments for IexecLayerZeroBridge..."
	@rlc_liquidity_unifier_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" sepolia rlcLiquidityUnifierAddress 2>/dev/null | grep "0x" | tail -n1); \
	lz_endpoint_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" sepolia lzEndpointAddress 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$(cast abi-encode "constructor(bool,address,address)" true $$rlc_liquidity_unifier_address $$lz_endpoint_address); \
	$(MAKE) _verify-layerzero-bridge-impl-sepolia CONSTRUCTOR_ARGS="--constructor-args $$constructor_args"

_verify-layerzero-bridge-impl-sepolia:
	$(call verify-impl,IexecLayerZeroBridge,sepolia,iexecLayerZeroBridgeAddress,$(SEPOLIA_CHAIN_ID),Sepolia Etherscan,src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge,$(SEPOLIA_RPC_URL),$(CONSTRUCTOR_ARGS))

# ========================================================================
#                          ARBITRUM SEPOLIA NETWORK VERIFICATION
# ========================================================================

# Proxy Verifications - Arbitrum Sepolia
# ---------------------------------------
verify-rlc-crosschain-token-proxy-arbitrum-sepolia:
	$(call verify-proxy,RLCCrosschainToken,arbitrum_sepolia,rlcCrosschainTokenAddress,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia)

verify-layerzero-bridge-proxy-arbitrum-sepolia:
	$(call verify-proxy,IexecLayerZeroBridge,arbitrum_sepolia,iexecLayerZeroBridgeAddress,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia)

# Implementation Verifications - Arbitrum Sepolia
# ------------------------------------------------
verify-rlc-crosschain-token-impl-arbitrum-sepolia:
	$(call verify-impl,RLCCrosschainToken,arbitrum_sepolia,rlcCrosschainTokenAddress,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia,src/RLCCrosschainToken.sol:RLCCrosschainToken,$(ARBITRUM_SEPOLIA_RPC_URL),)

verify-layerzero-bridge-impl-arbitrum-sepolia:
	@echo "Building constructor arguments for IexecLayerZeroBridge..."
	@rlc_crosschain_token_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" arbitrum_sepolia rlcCrosschainTokenAddress 2>/dev/null | grep "0x" | tail -n1); \
	lz_endpoint_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string,string)" arbitrum_sepolia lzEndpointAddress 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$(cast abi-encode "constructor(bool,address,address)" false $$rlc_crosschain_token_address $$lz_endpoint_address); \
	$(MAKE) _verify-layerzero-bridge-impl-arbitrum-sepolia CONSTRUCTOR_ARGS="--constructor-args $$constructor_args"

_verify-layerzero-bridge-impl-arbitrum-sepolia:
	$(call verify-impl,IexecLayerZeroBridge,arbitrum_sepolia,iexecLayerZeroBridgeAddress,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia,src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge,$(ARBITRUM_SEPOLIA_RPC_URL),$(CONSTRUCTOR_ARGS))

# ========================================================================
#							PROXY AND IMPLEMENTATION VERIFICATION
# ========================================================================
verify-proxies-sepolia: verify-rlc-liquidity-unifier-proxy-sepolia verify-layerzero-bridge-proxy-sepolia
verify-proxies-arbitrum-sepolia: verify-rlc-crosschain-token-proxy-arbitrum-sepolia verify-layerzero-bridge-proxy-arbitrum-sepolia
verify-proxies-testnets: verify-proxies-sepolia verify-proxies-arbitrum-sepolia

verify-implementations-sepolia: verify-rlc-liquidity-unifier-impl-sepolia verify-layerzero-bridge-impl-sepolia
verify-implementations-arbitrum-sepolia: verify-rlc-crosschain-token-impl-arbitrum-sepolia verify-layerzero-bridge-impl-arbitrum-sepolia
verify-implementations-testnets: verify-implementations-sepolia verify-implementations-arbitrum-sepolia


# ========================================================================
#							COMPLETION TARGETS
# ========================================================================

verify-all-sepolia: verify-proxies-sepolia verify-implementations-sepolia
verify-all-arbitrum-sepolia: verify-proxies-arbitrum-sepolia verify-implementations-arbitrum-sepolia
verify-all-testnets: verify-all-sepolia verify-all-arbitrum-sepolia


.PHONY: verify-all-testnets verify-all-sepolia verify-all-arbitrum-sepolia \
        verify-proxies-sepolia verify-proxies-arbitrum-sepolia verify-proxies-testnets \
        verify-implementations-sepolia verify-implementations-arbitrum-sepolia verify-implementations-testnets
