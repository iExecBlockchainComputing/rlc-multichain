# Makefile for RLC OFT Project
-include .env

.PHONY: deploy-test
# Default target
help:
	@echo "Available commands:"
	@echo "  make deploy-adapter         - Deploy the RLCAdapter contract"
	@echo "  make deploy-oft             - Deploy the RLCOFT contract"
	@echo "  make verify-adapter         - Verify the RLCAdapter contract on Etherscan"
	@echo "  make verify-oft             - Verify the RLCOFT contract on Etherscan"
	@echo "  make send-tokens            - Send tokens cross-chain"
	@echo "  make estimate-fee           - Estimate fee for cross-chain transfer"
	@echo "  make set-trusted-remote     - Set trusted remote for cross-chain communication"
	@echo "  make set-receive-handler    - Set handler for token reception"
	@echo "  make burn                   - Burn tokens"
	@echo "  make test                   - Run tests"
	@echo "  make clean                  - Clean artifacts"
	@echo ""
	@echo "Usage: make COMMAND [ACCOUNT=...] [...]"

# Deployment targets
deploy-adapter:
	@echo "Deploying RLCAdapter on SEPOLIA..."
	forge script script/RLCAdapter.s.sol:DeployRLCAdapter \
	--rpc-url $(SEPOLIA_RPC_URL) \
	--account $(ACCOUNT) \
	--broadcast \
	-vvv 

deploy-oft:
	@echo "Deploying RLCOFT on Arbitrum SEPOLIA..."
	forge script script/RLCOFT.s.sol:DeployRLCOFT \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv \

conf-adapter:
	@echo "Configuring RLCAdapter on SEPOLIA..."
	forge script script/ConfigureRLCAdapter.s.sol:ConfigureRLCAdapter \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv
conf-oft:
	@echo "Configuring RLCOFT on Arbitrum SEPOLIA..."
	forge script script/ConfigureRLCOFT.s.sol:ConfigureRLCOFT \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

send-tokens:
	@echo "Sending tokens cross-chain... from SEPOLIA to Arbitrum SEPOLIA"
	forge script script/SendEthereumToArbitrum.s.sol:SendEthereumToArbitrum \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

.PHONY: send-tokens-arbitrum-sepolia
send-tokens-arbitrum-sepolia:
	@echo "Sending tokens cross-chain... from Arbitrum SEPOLIA to SEPOLIA"
	@source .env && forge script script/SendArbitrumToEthereum.s.sol:SendArbitrumToEthereum \
		--rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) \
		--account $(ACCOUNT) \
        --broadcast \
        -vvv
# set-receive-handler:
# 	@echo "Setting receive handler..."
# 	forge script script/SetReceiveHandler.s.sol:SetReceiveHandlerScript \
# 		--rpc-url SEPOLIA \
# 		--account $(ACCOUNT) \
# 		--broadcast \
# 		-vvv
# # Verification targets
# .PHONY: verify-adapter
# verify-adapter:
# 	@echo "Verifying RLCAdapter on SEPOLIA..."
# 	forge verify-contract \
# 		--chain-id $(shell forge chain-id --rpc-url SEPOLIA) \
# 		--compiler-version v0.8.22 \
# 		--constructor-args $(shell cast abi-encode "constructor(address,address,address)" $(RLC_SEPOLIA_ADDRESS) $(SEPOLIA_ENDPOINT_ADDRESS) $(DELEGATE_ADDRESS)) \
# 		--etherscan-api-key $(BLOCKSCAN_API_KEY) \
# 		$(SEPOLIA_ADAPTER_ADDRESS) \
# 		src/RLCAdapter.sol:RLCAdapter

# .PHONY: verify-oft
# verify-oft:
# 	@echo "Verifying RLCOFT on SEPOLIA..."
# 	forge verify-contract \
# 		--chain-id $(shell forge chain-id --rpc-url SEPOLIA) \
# 		--compiler-version v0.8.22 \
# 		--constructor-args $(shell cast abi-encode "constructor(string,string,address,address)" $(TOKEN_NAME) $(TOKEN_SYMBOL) $(SEPOLIA_ENDPOINT_ADDRESS) $(DELEGATE_ADDRESS)) \
# 		--etherscan-api-key $(BLOCKSCAN_API_KEY) \
# 		$(ARBITRUM_SEPOLIA_OFT_ADDRESS) \
# 		src/RLCOFT.sol:RLCOFT

# Interaction targets


estimate-fee:
	@echo "Estimating fee for cross-chain transfer..."
	forge script script/EstimateFee.s.sol:EstimateFeeScript \
		--rpc-url SEPOLIA \
		--account $(ACCOUNT) \
		-vvv



burn:
	@echo "Burning tokens..."
	forge script script/BurnTokens.s.sol:BurnTokensScript \
		--rpc-url SEPOLIA \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

# Test and utility targets
test:
	@echo "Running tests..."
	forge test -vvv

clean:
	@echo "Cleaning artifacts..."
	forge clean
