
# ========================================================================
#                          SMART CONTRACT VERIFICATION
# ========================================================================
# Chain IDs for supported networks
MAINNET_CHAIN_ID := 1
ARBITRUM_CHAIN_ID := 42161
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
		$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(2).$(3)" 2>/dev/null | grep "0x" | tail -n1) \
		lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy
	@echo "Proxy verification completed for $(1) on $(5)"
endef

# Verify implementation contracts with optional constructor arguments
# Parameters: CONTRACT_NAME, NETWORK, CONFIG_KEY, CHAIN_ID, DISPLAY_NAME, CONTRACT_PATH, RPC_URL, CONSTRUCTOR_ARGS
define verify-impl
	@echo "Verifying $(1) Implementation on $(5)..."
	@proxy_address=$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(2).$(3)" 2>/dev/null | grep "0x" | tail -n1); \
	impl_address=$$(forge script script/GetConfigInfo.s.sol --sig "getImplementationAddress(string)" ".chains.$(2).$(3)" --rpc-url $(7) 2>/dev/null | grep "0x" | tail -n1); \
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
#                          ETHEREUM-TYPE VERIFICATION (Ethereum & Sepolia)
# ========================================================================

# Ethereum-type networks use RLC Liquidity Unifier + LayerZero Bridge
# Parameters: NETWORK, CHAIN_ID, DISPLAY_NAME, RPC_URL_VAR
define verify-ethereum-type-proxies
verify-rlc-liquidity-unifier-proxy-$(1):
	$$(call verify-proxy,RLCLiquidityUnifier,$(1),rlcLiquidityUnifierAddress,$(2),$(3))

verify-layerzero-bridge-proxy-$(1):
	$$(call verify-proxy,IexecLayerZeroBridge,$(1),iexecLayerZeroBridgeAddress,$(2),$(3))
endef

define verify-ethereum-type-implementations
verify-rlc-liquidity-unifier-impl-$(1):
	@rlc_address=$$$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(1).rlcAddress" 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$$$(cast abi-encode "constructor(address)" $$$$rlc_address); \
	$$(MAKE) _verify-rlc-liquidity-unifier-impl-$(1) CONSTRUCTOR_ARGS="--constructor-args $$$$constructor_args"

_verify-rlc-liquidity-unifier-impl-$(1):
	$$(call verify-impl,RLCLiquidityUnifier,$(1),rlcLiquidityUnifierAddress,$(2),$(3),src/RLCLiquidityUnifier.sol:RLCLiquidityUnifier,$$($(4)),$$(CONSTRUCTOR_ARGS))

verify-layerzero-bridge-impl-$(1):
	@echo "Building constructor arguments for IexecLayerZeroBridge..."
	@rlc_liquidity_unifier_address=$$$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(1).rlcLiquidityUnifierAddress" 2>/dev/null | grep "0x" | tail -n1); \
	lz_endpoint_address=$$$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(1).lzEndpointAddress" 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$$$(cast abi-encode "constructor(bool,address,address)" true $$$$rlc_liquidity_unifier_address $$$$lz_endpoint_address); \
	$$(MAKE) _verify-layerzero-bridge-impl-$(1) CONSTRUCTOR_ARGS="--constructor-args $$$$constructor_args"

_verify-layerzero-bridge-impl-$(1):
	$$(call verify-impl,IexecLayerZeroBridge,$(1),iexecLayerZeroBridgeAddress,$(2),$(3),src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge,$$($(4)),$$(CONSTRUCTOR_ARGS))
endef

# ========================================================================
#                          ARBITRUM-TYPE VERIFICATION (Arbitrum & Arbitrum Sepolia)
# ========================================================================

# Arbitrum-type networks use RLC Crosschain Token + LayerZero Bridge
# Parameters: NETWORK, CHAIN_ID, DISPLAY_NAME, RPC_URL_VAR
define verify-arbitrum-type-proxies
verify-rlc-crosschain-token-proxy-$(1):
	$$(call verify-proxy,RLCCrosschainToken,$(1),rlcCrosschainTokenAddress,$(2),$(3))

verify-layerzero-bridge-proxy-$(1):
	$$(call verify-proxy,IexecLayerZeroBridge,$(1),iexecLayerZeroBridgeAddress,$(2),$(3))
endef

define verify-arbitrum-type-implementations
verify-rlc-crosschain-token-impl-$(1):
	$$(call verify-impl,RLCCrosschainToken,$(1),rlcCrosschainTokenAddress,$(2),$(3),src/RLCCrosschainToken.sol:RLCCrosschainToken,$$($(4)),)

verify-layerzero-bridge-impl-$(1):
	@echo "Building constructor arguments for IexecLayerZeroBridge..."
	@rlc_crosschain_token_address=$$$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(1).rlcCrosschainTokenAddress" 2>/dev/null | grep "0x" | tail -n1); \
	lz_endpoint_address=$$$$(forge script script/GetConfigInfo.s.sol --sig "getConfigField(string)" ".chains.$(1).lzEndpointAddress" 2>/dev/null | grep "0x" | tail -n1); \
	constructor_args=$$$$(cast abi-encode "constructor(bool,address,address)" false $$$$rlc_crosschain_token_address $$$$lz_endpoint_address); \
	$$(MAKE) _verify-layerzero-bridge-impl-$(1) CONSTRUCTOR_ARGS="--constructor-args $$$$constructor_args"

_verify-layerzero-bridge-impl-$(1):
	$$(call verify-impl,IexecLayerZeroBridge,$(1),iexecLayerZeroBridgeAddress,$(2),$(3),src/bridges/layerZero/IexecLayerZeroBridge.sol:IexecLayerZeroBridge,$$($(4)),$$(CONSTRUCTOR_ARGS))
endef

# ========================================================================
#                          NETWORK-SPECIFIC VERIFICATION TARGETS
# ========================================================================

# Generate verification targets for Ethereum-type networks (Ethereum & Sepolia)
$(eval $(call verify-ethereum-type-proxies,sepolia,$(SEPOLIA_CHAIN_ID),Sepolia,SEPOLIA_RPC_URL))
$(eval $(call verify-ethereum-type-implementations,sepolia,$(SEPOLIA_CHAIN_ID),Sepolia,SEPOLIA_RPC_URL))

$(eval $(call verify-ethereum-type-proxies,ethereum,$(MAINNET_CHAIN_ID),Ethereum Mainnet,ETHEREUM_RPC_URL))
$(eval $(call verify-ethereum-type-implementations,ethereum,$(MAINNET_CHAIN_ID),Ethereum Mainnet,ETHEREUM_RPC_URL))

# Generate verification targets for Arbitrum-type networks (Arbitrum & Arbitrum Sepolia)  
$(eval $(call verify-arbitrum-type-proxies,arbitrum_sepolia,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia,ARBITRUM_SEPOLIA_RPC_URL))
$(eval $(call verify-arbitrum-type-implementations,arbitrum_sepolia,$(ARBITRUM_SEPOLIA_CHAIN_ID),Arbitrum Sepolia,ARBITRUM_SEPOLIA_RPC_URL))

$(eval $(call verify-arbitrum-type-proxies,arbitrum,$(ARBITRUM_CHAIN_ID),Arbitrum Mainnet,ARBITRUM_RPC_URL))
$(eval $(call verify-arbitrum-type-implementations,arbitrum,$(ARBITRUM_CHAIN_ID),Arbitrum Mainnet,ARBITRUM_RPC_URL))

# ========================================================================
#							PROXY AND IMPLEMENTATION VERIFICATION
# ========================================================================
verify-proxies-sepolia: verify-rlc-liquidity-unifier-proxy-sepolia verify-layerzero-bridge-proxy-sepolia
verify-proxies-arbitrum-sepolia: verify-rlc-crosschain-token-proxy-arbitrum_sepolia verify-layerzero-bridge-proxy-arbitrum_sepolia
verify-proxies-ethereum: verify-rlc-liquidity-unifier-proxy-ethereum verify-layerzero-bridge-proxy-ethereum
verify-proxies-arbitrum: verify-rlc-crosschain-token-proxy-arbitrum verify-layerzero-bridge-proxy-arbitrum

verify-implementations-sepolia: verify-rlc-liquidity-unifier-impl-sepolia verify-layerzero-bridge-impl-sepolia
verify-implementations-arbitrum-sepolia: verify-rlc-crosschain-token-impl-arbitrum_sepolia verify-layerzero-bridge-impl-arbitrum_sepolia
verify-implementations-ethereum: verify-rlc-liquidity-unifier-impl-ethereum verify-layerzero-bridge-impl-ethereum
verify-implementations-arbitrum: verify-rlc-crosschain-token-impl-arbitrum verify-layerzero-bridge-impl-arbitrum


# ========================================================================
#							COMPLETION TARGETS
# ========================================================================

verify-all-sepolia: verify-proxies-sepolia verify-implementations-sepolia
verify-all-arbitrum-sepolia: verify-proxies-arbitrum-sepolia verify-implementations-arbitrum-sepolia
verify-all-ethereum: verify-proxies-ethereum verify-implementations-ethereum
verify-all-arbitrum: verify-proxies-arbitrum verify-implementations-arbitrum
verify-all-testnets: verify-all-sepolia verify-all-arbitrum-sepolia
verify-all-mainnets: verify-all-ethereum verify-all-arbitrum
verify-all: verify-all-testnets verify-all-mainnets


.PHONY: verify-all verify-all-testnets verify-all-mainnets verify-all-sepolia verify-all-arbitrum-sepolia verify-all-ethereum verify-all-arbitrum \
        verify-proxies-sepolia verify-proxies-arbitrum-sepolia verify-proxies-ethereum verify-proxies-arbitrum \
        verify-implementations-sepolia verify-implementations-arbitrum-sepolia verify-implementations-ethereum verify-implementations-arbitrum
