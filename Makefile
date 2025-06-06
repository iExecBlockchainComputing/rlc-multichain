# Makefile for RLC OFT Project

MAKEFLAGS += --no-print-directory

-include .env

#
# Test and utility targets
#

fork-sepolia:
	anvil --fork-url $(SEPOLIA_RPC_URL) --port 8545

fork-arbitrum-sepolia:
	anvil --fork-url $(ARBITRUM_SEPOLIA_RPC_URL) --port 8546

unit-test:
	FOUNDRY_PROFILE=test forge test -vvvv --match-path "./test/units/**" --fail-fast

e2e-test:
	FOUNDRY_PROFILE=test forge test -vvvv --match-path "./test/e2e/**" --fail-fast

upgrade-test:
	FOUNDRY_PROFILE=test forge test -vvvvv --match-path "./test/upgrade/**" --fail-fast

clean:
	forge clean

#
# Deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-oft RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-oft RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-oft RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-oft RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-oft RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-oft RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

deploy-adapter:
	@echo "Deploying RLCAdapter (UUPS Proxy) on: $(RPC_URL)"
	forge script script/RLCAdapter.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

deploy-oft:
	@echo "Deploying RLCOFT (UUPS Proxy) on: $(RPC_URL)"
	forge script script/RLCOFT.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-adapter:
	@echo "Configuring RLCAdapter on: $(RPC_URL)..."
	forge script script/RLCAdapter.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

configure-oft:
	@echo "Configuring RLCOFT on: $(RPC_URL)"
	forge script script/RLCOFT.s.sol:Configure \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

#
# Upgrade targets
#

validate-adapter-upgrade:
	@echo "Validating RLCAdapter upgrade on: $(RPC_URL)"
	forge script script/RLCAdapter.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

validate-oft-upgrade:
	@echo "Validating RLCOFT upgrade on: $(RPC_URL)"
	forge script script/RLCOFT.s.sol:ValidateUpgrade \
        --rpc-url $(RPC_URL) \
        -vvv

upgrade-adapter:
	@echo "Upgrading RLCAdapter on: $(RPC_URL)"
	$(MAKE) validate-adapter-upgrade
	forge script script/RLCAdapter.s.sol:Upgrade \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

upgrade-oft:
	@echo "Upgrading RLCOFT on: $(RPC_URL)"
	$(MAKE) validate-oft-upgrade
	forge script script/RLCOFT.s.sol:Upgrade \
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

# Verification targets
verify-adapter:
	@echo "Verifying RLCAdapter Implementation on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,address)" $(RLC_SEPOLIA_ADDRESS) $(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_SEPOLIA_ADAPTER_IMPLEMENTATION_ADDRESS) \
        src/RLCAdapter.sol:RLCAdapter

verify-oft:
	@echo "Verifying RLCOFT Implementation on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address)" $(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS) \
        src/RLCOFT.sol:RLCOFT

# Combined verification target
verify-all: verify-adapter verify-oft

