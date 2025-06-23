# ===============================================
# AUDIT COMMANDS
# ===============================================

# Main audit command - runs clean then report
audit: 
	$(MAKE) clean-audit
	$(MAKE) audit-report

audit-report:
	@echo "🔍 GENERATING COMPREHENSIVE AUDIT REPORT"
	@echo "========================================"
	@mkdir -p audit-report
	@echo "📊 Report generated on: $$(date)" > audit/audit-report.txt
	@echo "" >> audit/audit-report.txt

	@echo "1. PROJECT SCOPE ANALYSIS" | tee -a audit/audit-report.txt
	@echo "=========================" | tee -a audit/audit-report.txt
	@echo "📁 Total Solidity Files:" | tee -a audit/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | wc -l | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "📏 Lines of Code Analysis (SLOC):" | tee -a audit/audit-report.txt
	@cloc src/ --include-lang=Solidity | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "📋 Lines per Solidity File:" | tee -a audit/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | xargs wc -l | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "🔐 SHA256 Hash of Contract Files:" | tee -a audit/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" -exec shasum -a 256 {} \; | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "2. SOLIDITY CODE METRICS" | tee -a audit/audit-report.txt
	@echo "========================" | tee -a audit/audit-report.txt
	$(eval SOL_FILES := $(shell find src/ -name '*.sol' -not -path "*/mocks/*"))
	@solidity-code-metrics $(SOL_FILES) --html > audit/code-metrics.html
	@echo "✅ Detailed code metrics saved to audit/code-metrics.html" | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "3. EXTERNAL CALLS ANALYSIS" | tee -a audit/audit-report.txt
	@echo "==========================" | tee -a audit/audit-report.txt
	@echo "🔍 External function calls found:" | tee -a audit/audit-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" -exec grep -Hn '\.[a-zA-Z_][a-zA-Z0-9_]*(' {} \; | head -50 | tee -a audit/audit-report.txt || echo "No external calls found" | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "4. COMPILATION & TESTING" | tee -a audit/audit-report.txt
	@echo "========================" | tee -a audit/audit-report.txt
	@echo "🔨 Running forge build..." | tee -a audit/audit-report.txt
	@forge clean
	@forge build 2>&1 | tail -1 | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "🧪 Running test suite..." | tee -a audit/audit-report.txt
	@forge test 2>&1 | tee audit/test-output.txt | grep -E "^(Ran [0-9]+.*:|Suite result:|Encountered.*failing|tests passed)" | tee -a audit/audit-report.txt
	@if grep -q "FAILED" audit/test-output.txt; then \
		echo "❌ Some tests are failing - see details below:" | tee -a audit/audit-report.txt; \
		grep "FAIL:" audit/test-output.txt | head -5 | tee -a audit/audit-report.txt; \
	else \
		echo "✅ All tests passed!" | tee -a audit/audit-report.txt; \
	fi
	@echo "" | tee -a audit/audit-report.txt

	@echo "5. STATIC ANALYSIS" | tee -a audit/audit-report.txt
	@echo "==================" | tee -a audit/audit-report.txt

	@echo "🐍 Slither Analysis" | tee -a audit/audit-report.txt
	@echo "  Running Slither analysis..." | tee -a audit/audit-report.txt
	@slither . --checklist 2>&1 | grep -A 10000 "THIS CHECKLIST IS NOT COMPLETE" | tee audit/slither-report.md
	@echo "  ✅ Slither report saved to audit/slither-report.md" | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "🔍 Aderyn Analysis" | tee -a audit/audit-report.txt
	@echo "  Running Aderyn analysis..." | tee -a audit/audit-report.txt
	@aderyn --output audit/aderyn-report.md 2>&1 | grep -E "(High|Medium|Low|Found|issues)" | tee -a audit/audit-report.txt
	@echo "  ✅ Aderyn report saved to audit/aderyn-report.md" | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt
		
	@echo "⚡ Mythril Analysis" | tee -a audit/audit-report.txt
	@echo "  Running Mythril analysis..." | tee -a audit/audit-report.txt
	@mkdir -p audit/mythril
	@for file in $$(find src/ -name '*.sol' -not -path "*/mocks/*" -not -path "*/interfaces/*"); do \
		echo "    Analyzing $$file..." | tee -a audit/audit-report.txt; \
		filename=$$(basename "$$file" .sol); \
		if [ -f mythril.config.json ]; then \
			myth analyze "$$file" --solc-json mythril.config.json -o markdown 2>/dev/null > "audit/mythril/$$filename-mythril.md" || echo "    ⚠️  Failed to analyze $$file" | tee -a audit/audit-report.txt; \
		else \
			myth analyze "$$file" -o markdown 2>/dev/null > "audit/mythril/$$filename-mythril.md" || echo "    ⚠️  Failed to analyze $$file" | tee -a audit/audit-report.txt; \
		fi; \
	done
	@echo "  ✅ Individual reports saved in audit/mythril/" | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "6. COVERAGE ANALYSIS" | tee -a audit/audit-report.txt
	@echo "====================" | tee -a audit/audit-report.txt
	@echo "📊 Test coverage report:" | tee -a audit/audit-report.txt
	@FOUNDRY_DISABLE_NIGHTLY_WARNING=true rm -rf coverage lcov.info lcov.src.info && \
	forge coverage --ir-minimum --report lcov --no-match-coverage "script|src/mocks|test" 2>&1 | \
		grep -E "(File|Overall coverage|Wrote LCOV)" | grep -v "^$$" | tee -a audit/audit-report.txt
	@if [ -f lcov.info ]; then \
		echo "🔍 Processing coverage data..." | tee -a audit/audit-report.txt; \
		genhtml lcov.info --branch-coverage --output-dir coverage 2>&1 | \
			grep -E "(Overall coverage rate|source files|lines\.\.\.\.\.\.\.|functions\.\.\.|branches\.\.\.|Message summary)" | \
			grep -v "^$$" | tee -a audit/audit-report.txt; \
		echo "✅ Coverage data saved to audit/" | tee -a audit/audit-report.txt; \
		echo "📈 HTML report generated in ./coverage/" | tee -a audit/audit-report.txt; \
		rm -f lcov.info 2>/dev/null || true; \
	else \
		echo "❌ Coverage analysis failed" | tee -a audit/audit-report.txt; \
	fi
	@echo "" | tee -a audit/audit-report.txt

	@echo "7. SECURITY PATTERNS CHECK" | tee -a audit/audit-report.txt
	@echo "===========================" | tee -a audit/audit-report.txt
	@echo "🔒 Checking for common patterns:" | tee -a audit/audit-report.txt
	@echo "- Reentrancy guards:" | tee -a audit/audit-report.txt
	@grep -r "nonReentrant\|ReentrancyGuard" src/ --include="*.sol" | wc -l | tee -a audit/audit-report.txt
	@echo "- Access control:" | tee -a audit/audit-report.txt
	@grep -r "onlyOwner\|AccessControl\|modifier" src/ --include="*.sol" | wc -l | tee -a audit/audit-report.txt
	@echo "- SafeMath usage:" | tee -a audit/audit-report.txt
	@grep -r "SafeMath\|using.*for" src/ --include="*.sol" | wc -l | tee -a audit/audit-report.txt
	@echo "" | tee -a audit/audit-report.txt

	@echo "✅ AUDIT REPORT COMPLETED" | tee -a audit/audit-report.txt
	@echo "=========================" | tee -a audit/audit-report.txt
	@echo "📁 Main report: audit/audit-report.txt" | tee -a audit/audit-report.txt
	@echo "📊 Files generated:" | tee -a audit/audit-report.txt
	@ls -la audit/ | tee -a audit/audit-report.txt


# Smart installer - checks then installs what it can
audit-install:
	@echo "🔧 CHECKING & INSTALLING AUDIT TOOLS"
	@echo "===================================="

	@echo "📦 Checking cloc..."
	@if command -v cloc >/dev/null 2>&1; then \
		echo "  ✅ cloc already installed"; \
	else \
		echo "  ⚠️  Installing cloc via npm..."; \
		npm install -g cloc; \
		echo "  ✅ cloc installed successfully"; \
	fi

	@echo "📊 Checking solidity-code-metrics..."
	@if command -v solidity-code-metrics >/dev/null 2>&1; then \
		echo "  ✅ solidity-code-metrics already installed"; \
	else \
		echo "  ⚠️  Installing solidity-code-metrics via npm..."; \
		npm install -g solidity-code-metrics; \
		echo "  ✅ solidity-code-metrics installed successfully"; \
	fi

	@echo "🐍 Checking Slither..."
	@if command -v slither >/dev/null 2>&1; then \
		echo "  ✅ Slither already installed"; \
	else \
		echo "  ⚠️  Installing Slither via pip3..."; \
		pip3 install slither-analyzer; \
		echo "  ✅ Slither installed successfully"; \
	fi

	@echo "🔍 Checking Aderyn..."
	@if command -v aderyn >/dev/null 2>&1; then \
		echo "  ✅ Aderyn already installed"; \
	else \
		echo "  ⚠️  Aderyn not installed. Manual installation required:"; \
		echo "     cargo install aderyn"; \
		echo "     or download from: https://github.com/cyfrin/aderyn"; \
	fi

	@echo "⚡ Checking Mythril..."
	@if command -v myth >/dev/null 2>&1; then \
		echo "  ✅ Mythril already installed"; \
	else \
		echo "  ⚠️  Mythril not installed. Manual installation required:"; \
		echo "     pipx install mythril"; \
		echo "     or: pip3 install mythril"; \
	fi

	@echo "📈 Checking genhtml (lcov)..."
	@if command -v genhtml >/dev/null 2>&1; then \
		echo "  ✅ genhtml already installed"; \
	else \
		echo "  ⚠️  genhtml not installed. Install via package manager:"; \
		echo "     macOS: brew install lcov"; \
		echo "     Ubuntu/Debian: sudo apt-get install lcov"; \
	fi

	@echo ""
	@echo "🎯 INSTALLATION SUMMARY"
	@echo "======================"
	@command -v cloc >/dev/null 2>&1 && echo "  ✅ cloc" || echo "  ❌ cloc"
	@command -v solidity-code-metrics >/dev/null 2>&1 && echo "  ✅ solidity-code-metrics" || echo "  ❌ solidity-code-metrics"
	@command -v slither >/dev/null 2>&1 && echo "  ✅ slither" || echo "  ❌ slither"
	@command -v aderyn >/dev/null 2>&1 && echo "  ✅ aderyn" || echo "  ❌ aderyn"
	@command -v myth >/dev/null 2>&1 && echo "  ✅ mythril" || echo "  ❌ mythril"
	@command -v genhtml >/dev/null 2>&1 && echo "  ✅ genhtml" || echo "  ❌ genhtml"


clean-audit:
	@echo "🧹 Cleaning audit reports..."
	rm -rf audit/
	@echo "✅ Audit reports cleaned!"

.PHONY: audit audit-report audit-install clean-audit 


