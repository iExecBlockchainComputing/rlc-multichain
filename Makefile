# Makefile for RLC OFT Project

MAKEFLAGS += --no-print-directory

-include .env

generate-coverage:
	rm -rf coverage lcov.info lcov.src.info && \
	forge coverage \
		--ir-minimum \
		--report lcov \
		--no-match-coverage "script|src/mocks" && \
	lcov --extract lcov.info "src/*" -o lcov.src.info && \
	genhtml lcov.src.info --branch-coverage --output-dir coverage

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
	FOUNDRY_PROFILE=test forge test -vvv --match-path "./test/units/**"

e2e-test:
	FOUNDRY_PROFILE=test forge test -vvv --match-path "./test/e2e/**"

upgrade-test:
	FOUNDRY_PROFILE=test forge test -vvv --match-path "./test/units/upgrade/**"

clean:
	forge clean

#
# Deployment targets
#

deploy-on-anvil:
	$(MAKE) deploy-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) deploy-rlc-crosschain-token RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-anvil:
	$(MAKE) upgrade-adapter RPC_URL=$(ANVIL_SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layerzero-bridge RPC_URL=$(ANVIL_ARBITRUM_SEPOLIA_RPC_URL)

deploy-on-testnets:
	$(MAKE) deploy-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) deploy-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)
	$(MAKE) configure-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) configure-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

upgrade-on-testnets:
	$(MAKE) upgrade-adapter RPC_URL=$(SEPOLIA_RPC_URL)
	$(MAKE) upgrade-layerzero-bridge RPC_URL=$(ARBITRUM_SEPOLIA_RPC_URL)

deploy-adapter:
	@echo "Deploying RLCAdapter (UUPS Proxy) on: $(RPC_URL)"
	forge script script/RLCAdapter.s.sol:Deploy \
        --rpc-url $(RPC_URL) \
        --account $(ACCOUNT) \
        --broadcast \
        -vvv

# deploy-rlc-crosschain-token RPC_URL=https://...
deploy-rlc-crosschain-token:
	@echo "Deploying RLC cross-chain token (UUPS Proxy) on : $(RPC_URL)"
	CHAIN=arbitrum_sepolia forge script script/RLCCrosschainToken.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--account $(ACCOUNT) \
		--broadcast \
		-vvv

deploy-layerzero-bridge:
	@echo "Deploying IexecLayerZeroBridge (UUPS Proxy) on: $(RPC_URL)"
	forge script script/IexecLayerZeroBridge.s.sol:Deploy \
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

configure-layerzero-bridge:
	@echo "Configuring RLCOFT on: $(RPC_URL)"
	forge script script/IexecLayerZeroBridge.s.sol:Configure \
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

validate-layerZero-bridge-upgrade:
	@echo "Validating RLC LayerZero upgrade on: $(RPC_URL)"
	forge script script/IexecLayerZeroBridge.s.sol:ValidateUpgrade \
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

upgrade-layerzero-bridge:
	@echo "Upgrading RLC LayerZero Bridge on: $(RPC_URL)"
	$(MAKE) validate-layerZero-bridge-upgrade
	forge script script/IexecLayerZeroBridge.s.sol:Upgrade \
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

# Implementation verification
verify-adapter-impl:
	@echo "Verifying RLCAdapter Implementation on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,address)" $(RLC_ADDRESS) $(LAYER_ZERO_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) \
        src/RLCAdapter.sol:RLCAdapter

verify-layerzero-bridge-impl:
	@echo "Verifying RLCOFT Implementation on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address)" $(LAYER_ZERO_ARBITRUM_SEPOLIA_ENDPOINT_ADDRESS)) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS) \
        src/RLCOFT.sol:RLCOFT

# Proxy verification
verify-adapter-proxy:
	@echo "Verifying RLCAdapter Proxy on Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 11155111 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ADAPTER_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ETHERSCAN_API_KEY) \
        $(RLC_SEPOLIA_ADAPTER_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

verify-layerzero-bridge-proxy:
	@echo "Verifying RLCOFT Proxy on Arbitrum Sepolia Etherscan..."
	forge verify-contract \
        --chain-id 421614 \
        --watch \
        --constructor-args $(shell cast abi-encode "constructor(address,bytes)" $(RLC_ARBITRUM_SEPOLIA_OFT_IMPLEMENTATION_ADDRESS) $(shell cast calldata "initialize(address,address)" $(OWNER_ADDRESS) $(PAUSER_ADDRESS))) \
        --etherscan-api-key $(ARBISCAN_API_KEY) \
        $(RLC_ARBITRUM_SEPOLIA_OFT_PROXY_ADDRESS) \
        lib/openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy

# Combined verification targets
verify-adapter: verify-adapter-impl verify-adapter-proxy
verify-layerzero-bridge: verify-layerzero-bridge-impl verify-layerzero-bridge-proxy

verify-implementations: verify-adapter-impl verify-layerzero-bridge-impl
verify-proxies: verify-adapter-proxy verify-layerzero-bridge-proxy
verify-all: verify-implementations verify-proxies


# Audit Preparation Report Command
audit-report:
	@echo "🔍 GENERATING COMPREHENSIVE AUDIT REPORT"
	@echo "========================================"
	@mkdir -p audit-report
	@echo "📊 Report generated on: $$(date)" > audit-report/audit-report.txt
	@echo "" >> audit-report/audit-report.txt
    
	@echo "1. PROJECT SCOPE ANALYSIS" | tee -a audit-report/audit-report.txt
	@echo "=========================" | tee -a audit-report/audit-report.txt

	@echo "📁 Total Solidity Files:" | tee -a audit-report/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | wc -l | tee -a audit-report/audit-report.txt
	@echo "" | tee -a audit-report/audit-report.txt

	@echo "📏 Lines of Code Analysis (SLOC):" | tee -a audit-report/audit-report.txt
	@if command -v cloc >/dev/null 2>&1; then \
		cloc src/ --include-lang=Solidity | tee -a audit-report/audit-report.txt; \
	else \
		echo "⚠️  cloc not installed. Installing via npm..."; \
		npm install -g cloc; \
		cloc src/ --include-lang=Solidity | tee -a audit-report/audit-report.txt; \
	fi
	@echo "" | tee -a audit-report/audit-report.txt

	@echo "📋 Lines per Solidity File:" | tee -a audit-report/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | xargs wc -l | tee -a audit-report/audit-report.txt
	@echo "" | tee -a audit-report/audit-report.txt

	@echo "🔐 SHA256 Hash of Contract Files:" | tee -a audit-report/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" -exec shasum -a 256 {} \; | tee -a audit-report/audit-report.txt
	@echo "" | tee -a audit-report/audit-report.txt


	@echo "2. SOLIDITY CODE METRICS" | tee -a audit-report/audit-report.txt
	@echo "========================" | tee -a audit-report/audit-report.txt
	$(eval SOL_FILES := $(shell find src/ -name '*.sol' -not -path "*/mocks/*"))
	@if command -v solidity-code-metrics >/dev/null 2>&1; then \
		solidity-code-metrics $(SOL_FILES) --html > audit-report/code-metrics.html; \
		echo "✅ Detailed code metrics saved to audit-report/code-metrics.html" | tee -a audit-report/audit-report.txt; \
	else \
		echo "⚠️  Installing solidity-code-metrics..."; \
		npm install -g solidity-code-metrics; \
		solidity-code-metrics $(SOL_FILES) --html > audit-report/code-metrics.html; \
		echo "✅ Detailed code metrics saved to audit-report/code-metrics.html" | tee -a audit-report/audit-report.txt; \
	fi
	@echo "" | tee -a audit-report/audit-report.txt

# @echo "3. EXTERNAL CALLS ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "==========================" | tee -a audit-report/audit-report.txt
# @echo "🔍 External function calls found:" | tee -a audit-report/audit-report.txt
# @find src/ -name '*.sol' -not -path "*/mocks/*" -exec grep -Hn '\.[a-zA-Z_][a-zA-Z0-9_]*(' {} \; | head -50 | tee -a audit-report/audit-report.txt || echo "No external calls found" | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt


# @echo "4. COMPILATION & TESTING" | tee -a audit-report/audit-report.txt
# @echo "========================" | tee -a audit-report/audit-report.txt
# @echo "🔨 Running forge build..." | tee -a audit-report/audit-report.txt
# @forge clean
# @forge build 2>&1 | tail -1 | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt

# @echo "🧪 Running test suite..." | tee -a audit-report/audit-report.txt
# @forge test 2>&1 | grep -E "^(Ran [0-9]+.*:|Suite result:|Encountered.*failing|tests passed)" | tee -a audit-report/audit-report.txt
# @if forge test 2>&1 | grep -q "FAILED"; then \
# 	echo "❌ Some tests are failing - see details below:" | tee -a audit-report/audit-report.txt; \
# 	forge test 2>&1 | grep "FAIL:" | head -5 | tee -a audit-report/audit-report.txt; \
# else \
# 	echo "✅ All tests passed!" | tee -a audit-report/audit-report.txt; \
# fi
# @echo "" | tee -a audit-report/audit-report.txt


# @echo "6. STATIC ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "==================" | tee -a audit-report/audit-report.txt
# @if command -v slither >/dev/null 2>&1; then \
# 	echo "🐍 Running Slither analysis..." | tee -a audit-report/audit-report.txt; \
# 	slither . --checklist 2>&1 | grep -A 10000 "THIS CHECKLIST IS NOT COMPLETE" | tee audit-report/slither-report.md; \
# 	echo "✅ Slither report saved to audit-report/slither-report.md" | tee -a audit-report/audit-report.txt; \
# else \
# 	echo "⚠️  Slither not installed. Please install: pip3 install slither-analyzer" | tee -a audit-report/audit-report.txt; \
# fi
# @echo "" | tee -a audit-report/audit-report.txt

	@echo "6. STATIC ANALYSIS" | tee -a audit-report/audit-report.txt
	@echo "==================" | tee -a audit-report/audit-report.txt
    
    # Slither Analysis
    # @if command -v slither >/dev/null 2>&1; then \
    #     echo "🐍 Running Slither analysis..." | tee -a audit-report/audit-report.txt; \
	# 	slither . --checklist 2>&1 | grep -A 10000 "THIS CHECKLIST IS NOT COMPLETE" | tee audit-report/slither-report.md; \
    #     echo "✅ Slither report saved to audit-report/slither-report.md" | tee -a audit-report/audit-report.txt; \
    # else \
    #     echo "⚠️  Slither not installed. Install with: pip3 install slither-analyzer" | tee -a audit-report/audit-report.txt; \
    # fi
    
# Aderyn Analysis
# @if command -v aderyn >/dev/null 2>&1; then \
# 	echo "🔍 Running Aderyn analysis..." | tee -a audit-report/audit-report.txt; \
# 	aderyn --output audit-report/aderyn-report.md 2>&1 | grep -E "(High|Medium|Low|Found|issues)" | tee -a audit-report/audit-report.txt; \
# 	echo "✅ Aderyn report saved to audit-report/aderyn-report.md" | tee -a audit-report/audit-report.txt; \
# else \
# 	echo "⚠️  Aderyn not installed. Install from: https://github.com/cyfrin/aderyn" | tee -a audit-report/audit-report.txt; \
# fi
    
    # Mythril Analysis
# @if command -v myth >/dev/null 2>&1; then \
# 	echo "⚡ Running Mythril analysis..." | tee -a audit-report/audit-report.txt; \
# 	if [ -f mythril.config.json ]; then \
# 		myth analyze src/ --solc-json mythril.config.json --output markdown > audit-report/mythril-report.md 2>&1; \
# 	else \
# 		myth analyze src/ --output markdown > audit-report/mythril-report.md 2>&1; \
# 	fi; \
# 	if [ -f audit-report/mythril-report.md ]; then \
# 		echo "✅ Mythril report saved to audit-report/mythril-report.md" | tee -a audit-report/audit-report.txt; \
# 	else \
# 		echo "❌ Mythril analysis failed" | tee -a audit-report/audit-report.txt; \
# 	fi; \
# else \
# 	echo "⚠️  Mythril not installed. Install with: pip3 install mythril" | tee -a audit-report/audit-report.txt; \
# fi

# @echo "" | tee -a audit-report/audit-report.txt



	@if command -v myth >/dev/null 2>&1; then \
		echo "⚡ Running Mythril analysis..." | tee -a audit-report/audit-report.txt; \
		mkdir -p audit-report/mythril; \
		for file in $$(find src/ -name '*.sol' -not -path "*/mocks/*" -not -path "*/interfaces/*"); do \
			echo "  Analyzing $$file..." | tee -a audit-report/audit-report.txt; \
			filename=$$(basename "$$file" .sol); \
			if [ -f mythril.config.json ]; then \
				myth analyze "$$file" --solc-json mythril.config.json -o markdown > "audit-report/mythril/$$filename-mythril.md" 2>&1; \
			else \
				myth analyze "$$file" -o markdown > "audit-report/mythril/$$filename-mythril.md" 2>&1; \
			fi; \
		done; \
		echo "📋 Consolidating Mythril reports..." | tee -a audit-report/audit-report.txt; \
		echo "# Mythril Analysis Report" > audit-report/mythril-report.md; \
		echo "Generated on: $$(date)" >> audit-report/mythril-report.md; \
		echo "" >> audit-report/mythril-report.md; \
		for file in audit-report/mythril/*-mythril.md; do \
			if [ -f "$$file" ]; then \
				filename=$$(basename "$$file" -mythril.md); \
				echo "## Analysis for $$filename.sol" >> audit-report/mythril-report.md; \
				echo "" >> audit-report/mythril-report.md; \
				cat "$$file" >> audit-report/mythril-report.md; \
				echo "" >> audit-report/mythril-report.md; \
				echo "---" >> audit-report/mythril-report.md; \
				echo "" >> audit-report/mythril-report.md; \
			fi; \
		done; \
		if [ -f audit-report/mythril-report.md ]; then \
			echo "✅ Mythril consolidated report saved to audit-report/mythril-report.md" | tee -a audit-report/audit-report.txt; \
			echo "✅ Individual reports saved in audit-report/mythril/" | tee -a audit-report/audit-report.txt; \
		else \
			echo "❌ Mythril analysis failed" | tee -a audit-report/audit-report.txt; \
		fi; \
	else \
		echo "⚠️  Mythril not installed. Install with: pipx install mythril" | tee -a audit-report/audit-report.txt; \
	fi

	@echo "" | tee -a audit-report/audit-report.txt


# @echo "9. COVERAGE ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "====================" | tee -a audit-report/audit-report.txt
# @echo "📊 Test coverage report:" | tee -a audit-report/audit-report.txt
# @FOUNDRY_DISABLE_NIGHTLY_WARNING=true rm -rf coverage lcov.info lcov.src.info && \
# forge coverage --ir-minimum --report lcov --no-match-coverage "script|src/mocks" 2>&1 | \
# 	grep -E "(File|Overall coverage|Wrote LCOV)" | grep -v "^$$" | tee -a audit-report/audit-report.txt
# @if [ -f lcov.info ]; then \
# 	echo "🔍 Processing coverage data..." | tee -a audit-report/audit-report.txt; \
# 	lcov --extract lcov.info "src/*" -o lcov.src.info --quiet; \
# 	genhtml lcov.src.info --branch-coverage --output-dir coverage 2>&1 | \
# 		grep -E "(Overall coverage rate|source files|lines\.\.\.\.\.\.\.|functions\.\.\.|branches\.\.\.|Message summary)" | \
# 		grep -v "^$$" | tee -a audit-report/audit-report.txt; \
# 	mv lcov.info lcov.src.info audit-report/ 2>/dev/null || true; \
# 	echo "✅ Coverage data saved to audit-report/" | tee -a audit-report/audit-report.txt; \
# 	echo "📈 HTML report generated in ./coverage/" | tee -a audit-report/audit-report.txt; \
# else \
# 	echo "❌ Coverage analysis failed" | tee -a audit-report/audit-report.txt; \
# fi
# @echo "" | tee -a audit-report/audit-report.txt


# @echo "10. SECURITY PATTERNS CHECK" | tee -a audit-report/audit-report.txt
# @echo "===========================" | tee -a audit-report/audit-report.txt
# @echo "🔒 Checking for common patterns:" | tee -a audit-report/audit-report.txt
# @echo "- Reentrancy guards:" | tee -a audit-report/audit-report.txt
# @grep -r "nonReentrant\|ReentrancyGuard" src/ --include="*.sol" | wc -l | tee -a audit-report/audit-report.txt
# @echo "- Access control:" | tee -a audit-report/audit-report.txt
# @grep -r "onlyOwner\|AccessControl\|modifier" src/ --include="*.sol" | wc -l | tee -a audit-report/audit-report.txt
# @echo "- SafeMath usage:" | tee -a audit-report/audit-report.txt
# @grep -r "SafeMath\|using.*for" src/ --include="*.sol" | wc -l | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt



# @echo "5. GAS ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "===============" | tee -a audit-report/audit-report.txt
# @echo "⛽ Gas usage for main operations:" | tee -a audit-report/audit-report.txt
# @forge test --gas-report 2>&1 | grep -E "

# $$
# PASS
# $$

# .*$ gas: [0-9]+ $ " | \
# grep -E "(sendRLC|sendToken|Deploy|Upgrade)" | \
# sed 's/

# $$
# PASS
# $$

# /  ✅ /' | sed 's/ (gas: / - Gas: /' | sed 's/)/ units/' | \
# head -8 | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt
# @echo "📈 Contract deployment costs:" | tee -a audit-report/audit-report.txt
# @forge test --gas-report 2>&1 | grep -A 2 "src/.*Contract" | grep -E "(src/|Deployment Cost)" | \
# paste - - | sed 's/.*src\/$ .* $ \.sol:$ .* $  Contract.* $ [0-9]* $ .*/  - \2: \3 gas/' | \
# head -5 | tee -a audit-report/audit-report.txt || echo "  No deployment data found" | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt

# @echo "7. DEPENDENCY ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "======================" | tee -a audit-report/audit-report.txt
# @echo "📦 Forge dependencies:" | tee -a audit-report/audit-report.txt
# @forge tree 2>&1 | grep -E "^[a-zA-Z]|^├──[^│]*$$|^└──[^│]*$$" | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt




# @echo "8. CONTRACT SIZE ANALYSIS" | tee -a audit-report/audit-report.txt
# @echo "=========================" | tee -a audit-report/audit-report.txt
# @echo "📏 Contract sizes (bytecode):" | tee -a audit-report/audit-report.txt
# @forge build --sizes 2>&1 | tee -a audit-report/audit-report.txt
# @echo "" | tee -a audit-report/audit-report.txt

# @echo "✅ AUDIT REPORT COMPLETE!" | tee -a audit-report/audit-report.txt
# @echo "=========================" | tee -a audit-report/audit-report.txt
# @echo "📁 All reports saved in ./audit-report/ directory" | tee -a audit-report/audit-report.txt
# @echo "📄 Main report: audit-report/audit-report.txt"
# @echo "📊 Code metrics: audit-report/code-metrics.html"
# @echo "📋 Coverage data: audit-report/lcov.info"
# @echo "🐍 Slither report: audit-report/slither-report.json"
# @echo ""
# @echo "🎯 Ready for audit submission!"

# Helper command to install audit dependencies
install-audit-deps:
	@echo "📦 Installing audit dependencies..."
	npm install -g cloc solidity-code-metrics
	pip3 install slither-analyzer
	@echo "✅ Dependencies installed!"

# Clean audit reports
clean-audit:
	@echo "🧹 Cleaning audit reports..."
	rm -rf audit-report/
	@echo "✅ Audit reports cleaned!"

audit: 
	make clean-audit
	make audit-report