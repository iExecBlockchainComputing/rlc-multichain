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


