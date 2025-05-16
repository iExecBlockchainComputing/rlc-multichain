# Makefile for RLC OFT Project
-include .env
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

# Verification targets
verify-adapter:
	@echo "Verifying RLCAdapter on Sepolia Etherscan..."
	forge verify-contract \
		--chain-id 11155111 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(address,address,address)" $(RLC_SEPOLIA_ADDRESS) $(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS) $(DELEGATE_ADDRESS)) \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		$(SEPOLIA_ADAPTER_ADDRESS) \
		src/RLCAdapter.sol:RLCAdapter

verify-oft:
	@echo "Verifying RLCOFT on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
		--chain-id 421614 \
		--watch \
		--constructor-args $(shell cast abi-encode "constructor(string,string,address,address)" $(TOKEN_NAME) $(TOKEN_SYMBOL) $(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS) $(DELEGATE_ADDRESS)) \
		--etherscan-api-key $(ARBISCAN_API_KEY) \
		$(ARBITRUM_SEPOLIA_OFT_ADDRESS) \
		src/RLCOFT.sol:RLCOFT

# Combined verification target
verify-all: verify-adapter verify-oft

# Test and utility targets
test:
	@echo "Running tests..."
	forge test -vvv

clean:
	@echo "Cleaning artifacts..."
	forge clean
