#
# Bridge pause/unpause operations
#

# Emergency pause - Level 1 (Complete pause: blocks all operations)
pause-bridge-single-chain: # CHAIN, RPC_URL
	@echo "🚨 EMERGENCY PAUSE: Stopping bridge operations on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/PauseBridge.s.sol:PauseBridge \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PAUSER_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv

# Unpause - Level 1 (Restore all operations)
unpause-bridge-single-chain: # CHAIN, RPC_URL
	@echo "✅ UNPAUSE: Restoring bridge operations on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/PauseBridge.s.sol:UnpauseBridge \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PAUSER_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv
# Outbound pause - Level 2 (Pause sends, allow receives)
pause-outbound-single-chain: # CHAIN, RPC_URL
	@echo "⚠️  OUTBOUND PAUSE: Blocking outbound transfers on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/PauseBridge.s.sol:PauseOutboundTransfers \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PAUSER_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv
# Unpause outbound - Level 2 (Restore sends)
unpause-outbound-single-chain: # CHAIN, RPC_URL 
	@echo "✅ UNPAUSE OUTBOUND: Restoring outbound transfers on $(CHAIN)"
	CHAIN=$(CHAIN) forge script script/PauseBridge.s.sol:UnpauseOutboundTransfers \
		--rpc-url $(RPC_URL) \
		$$(if [ "$(CI)" = "true" ]; then echo "--private-key $(PAUSER_PRIVATE_KEY)"; else echo "--account $(ACCOUNT)"; fi) \
		--broadcast \
		-vvv