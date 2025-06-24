# ===============================================
# IEXEC REPORT COMMANDS
# ===============================================

# Main report command - runs clean then report
report:
	$(MAKE) clean-report
	$(MAKE) iexec-internal-report

iexec-internal-report:
	@echo "🔍 GENERATING COMPREHENSIVE IEXEC REPORT"
	@echo "========================================"
	@mkdir -p iexec-report
	@echo "📊 Report generated on: $$(date)" > iexec-report/iexec-automatic-report.txt
	@echo "" >> iexec-report/iexec-automatic-report.txt

	@echo "1. PROJECT SCOPE ANALYSIS" | tee -a iexec-report/iexec-automatic-report.txt
	@echo "=========================" | tee -a iexec-report/iexec-automatic-report.txt
	@echo "📁 Total Solidity Files:" | tee -a iexec-report/iexec-automatic-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | wc -l | tee -a iexec-report/iexec-automatic-report.txt
	@echo "" | tee -a iexec-report/iexec-automatic-report.txt

	@echo "📏 Lines of Code Analysis (SLOC):" | tee -a iexec-report/iexec-automatic-report.txt
	@cloc src/ --include-lang=Solidity | tee -a iexec-report/iexec-automatic-report.txt
	@echo "" | tee -a iexec-report/iexec-automatic-report.txt

	@echo "📋 Lines per Solidity File:" | tee -a iexec-report/iexec-automatic-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" | xargs wc -l | tee -a iexec-report/iexec-automatic-report.txt
	@echo "" | tee -a iexec-report/iexec-automatic-report.txt

	@echo "🔐 SHA256 Hash of Contract Files:" | tee -a iexec-report/iexec-automatic-report.txt
	@find src/ -name '*.sol' -not -path "*/mocks/*" -exec shasum -a 256 {} \; | tee -a iexec-report/iexec-automatic-report.txt
	@echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "2. SOLIDITY CODE METRICS" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "========================" | tee -a iexec-report/iexec-automatic-report.txt
# $(eval SOL_FILES := $(shell find src/ -name '*.sol' -not -path "*/mocks/*"))
# @solidity-code-metrics $(SOL_FILES) --html > iexec-report/code-metrics.html
# @echo "✅ Detailed code metrics saved to iexec-report/code-metrics.html" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "3. EXTERNAL CALLS ANALYSIS" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "==========================" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "🔍 External function calls found:" | tee -a iexec-report/iexec-automatic-report.txt
# @find src/ -name '*.sol' -not -path "*/mocks/*" -exec grep -Hn '\.[a-zA-Z_][a-zA-Z0-9_]*(' {} \; | head -50 | tee -a iexec-report/iexec-automatic-report.txt || echo "No external calls found" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "4. COMPILATION & TESTING" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "========================" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "🔨 Running forge build..." | tee -a iexec-report/iexec-automatic-report.txt
# @forge clean
# @forge build 2>&1 | tail -1 | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "🧪 Running test suite..." | tee -a iexec-report/iexec-automatic-report.txt
# @forge test 2>&1 | tee iexec-report/test-output.txt | grep -E "^(Ran [0-9]+.*:|Suite result:|Encountered.*failing|tests passed)" | tee -a iexec-report/iexec-automatic-report.txt
# @if grep -q "FAILED" iexec-report/test-output.txt; then \
# 	echo "❌ Some tests are failing - see details below:" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	grep "FAIL:" iexec-report/test-output.txt | head -5 | tee -a iexec-report/iexec-automatic-report.txt; \
# else \
# 	echo "✅ All tests passed!" | tee -a iexec-report/iexec-automatic-report.txt; \
# fi
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "5. STATIC ANALYSIS" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "==================" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "🐍 Slither Analysis" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "  Running Slither analysis..." | tee -a iexec-report/iexec-automatic-report.txt
# @slither . --checklist 2>&1 | grep -A 10000 "THIS CHECKLIST IS NOT COMPLETE" | tee iexec-report/slither-report.md
# @echo "  ✅ Slither report saved to iexec-report/slither-report.md" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "🔍 Aderyn Analysis" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "  Running Aderyn analysis..." | tee -a iexec-report/iexec-automatic-report.txt
# @aderyn --output iexec-report/aderyn-report.md 2>&1 | grep -E "(High|Medium|Low|Found|issues)" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "  ✅ Aderyn report saved to iexec-report/aderyn-report.md" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "⚡ Mythril Analysis" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "  Running Mythril analysis..." | tee -a iexec-report/iexec-automatic-report.txt
# @mkdir -p iexec-report/mythril
# @for file in $$(find src/ -name '*.sol' -not -path "*/mocks/*" -not -path "*/interfaces/*"); do \
# 	echo "    Analyzing $$file..." | tee -a iexec-report/iexec-automatic-report.txt; \
# 	filename=$$(basename "$$file" .sol); \
# 	if [ -f mythril.config.json ]; then \
# 		myth analyze "$$file" --solc-json mythril.config.json -o markdown 2>/dev/null > "iexec-report/mythril/$$filename-mythril.md" || echo "    ⚠️  Failed to analyze $$file" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	else \
# 		myth analyze "$$file" -o markdown 2>/dev/null > "iexec-report/mythril/$$filename-mythril.md" || echo "    ⚠️  Failed to analyze $$file" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	fi; \
# done
# @echo "  ✅ Individual reports saved in iexec-report/mythril/" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "6. COVERAGE ANALYSIS" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "====================" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "📊 Test coverage report:" | tee -a iexec-report/iexec-automatic-report.txt
# @FOUNDRY_DISABLE_NIGHTLY_WARNING=true rm -rf coverage lcov.info lcov.src.info && \
# forge coverage --ir-minimum --report lcov --no-match-coverage "script|src/_mocks|test" 2>&1 | \
# 	grep -E "(File|Overall coverage|Wrote LCOV)" | grep -v "^$$" | tee -a iexec-report/iexec-automatic-report.txt
# @if [ -f lcov.info ]; then \
# 	echo "🔍 Processing coverage data..." | tee -a iexec-report/iexec-automatic-report.txt; \
# 	genhtml lcov.info --branch-coverage --output-dir coverage 2>&1 | \
# 		grep -E "(Overall coverage rate|source files|lines\.\.\.\.\.\.\.|functions\.\.\.|branches\.\.\.|Message summary)" | \
# 		grep -v "^$$" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	echo "✅ Coverage data saved to iexec-report/" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	echo "📈 HTML report generated in ./coverage/" | tee -a iexec-report/iexec-automatic-report.txt; \
# 	rm -f lcov.info 2>/dev/null || true; \
# else \
# 	echo "❌ Coverage analysis failed" | tee -a iexec-report/iexec-automatic-report.txt; \
# fi
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

# @echo "7. SECURITY PATTERNS CHECK" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "===========================" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "🔒 Checking for common patterns:" | tee -a iexec-report/iexec-automatic-report.txt
# @echo "- Reentrancy guards:" | tee -a iexec-report/iexec-automatic-report.txt
# @grep -r "nonReentrant\|ReentrancyGuard" src/ --include="*.sol" | wc -l | tee -a iexec-report/iexec-automatic-report.txt
# @echo "- Access control:" | tee -a iexec-report/iexec-automatic-report.txt
# @grep -r "onlyOwner\|AccessControl\|modifier" src/ --include="*.sol" | wc -l | tee -a iexec-report/iexec-automatic-report.txt
# @echo "- SafeMath usage:" | tee -a iexec-report/iexec-automatic-report.txt
# @grep -r "SafeMath\|using.*for" src/ --include="*.sol" | wc -l | tee -a iexec-report/iexec-automatic-report.txt
# @echo "" | tee -a iexec-report/iexec-automatic-report.txt

	@echo "✅ REPORT COMPLETED" | tee -a iexec-report/iexec-automatic-report.txt
	@echo "=========================" | tee -a iexec-report/iexec-automatic-report.txt
	@echo "📁 Main report: iexec-report/iexec-automatic-report.txt" | tee -a iexec-report/iexec-automatic-report.txt
	@echo "📊 Files generated:" | tee -a iexec-report/iexec-automatic-report.txt
	@ls -la iexec-report/ | tee -a iexec-report/iexec-automatic-report.txt


# Smart installer - checks then installs what it can
iexec-internal-install:
	@echo "🔧 CHECKING & INSTALLING TOOLS"
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


clean-report:
	@echo "🧹 Cleaning reports..."
	rm -rf iexec-report/
	@echo "✅ Reports cleaned!"

.PHONY: report iexec-internal-report iexec-internal-install clean-report


