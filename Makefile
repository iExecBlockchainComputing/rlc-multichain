# Makefile for RLC OFT Project
-include .env
# Configuration
NETWORK ?= sepolia
RPC_URL_SEPOLIA ?="https://lb.drpc.org/ogrpc?network=sepolia&dkey=<>"
RPC_URL_ARBITRUM_SEPOLIA ?= "https://lb.drpc.org/ogrpc?network=arbitrum-sepolia&dkey=<>"
ETHERSCAN_API_KEY ?= <>
ACCOUNT ?= iexec-gabriel-mm-dev

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
	@echo "Usage: make COMMAND [NETWORK=sepolia|arbitrum_sepolia] [ACCOUNT=...] [...]"

# Deployment targets
deploy-adapter:
	@echo "Deploying RLCAdapter on $(NETWORK)..."
	forge script script/RLCAdapter.s.sol:DeployRLCAdapter \
	--rpc-url $(RPC_URL_SEPOLIA) \
	--account $(ACCOUNT) \
	--broadcast \
	-vvv 

deploy-oft:
	@echo "Deploying RLCOFT on $(NETWORK)..."
	forge script script/RLCOFT.s.sol:DeployRLCOFT \
		--rpc-url $(RPC_URL_ARBITRUM_SEPOLIA) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv \

conf-adapter:
	@echo "Configuring RLCAdapter on $(NETWORK)..."
	forge script script/ConfigureRLCAdapter.s.sol:ConfigureRLCAdapter \
		--rpc-url $(RPC_URL_SEPOLIA) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv
conf-oft:
	@echo "Configuring RLCOFT on $(NETWORK)..."
	forge script script/ConfigureRLCOFT.s.sol:ConfigureRLCOFT \
		--rpc-url $(RPC_URL_ARBITRUM_SEPOLIA) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

send-tokens:
	@echo "Sending tokens cross-chain..."
	forge script script/SendEthereumToArbitrum.s.sol:SendEthereumToArbitrum \
		--rpc-url $(RPC_URL_SEPOLIA) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv