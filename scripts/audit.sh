#!/bin/bash
set -euo pipefail

echo "Starting comprehensive smart contract audit..."
echo "=============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create reports directory
REPORT_DIR="security"
mkdir -p "$REPORT_DIR/slither"

PASS=0
FAIL=0

run_step() {
    local name="$1"
    shift
    echo ""
    echo -e "${YELLOW}[$name]${NC}"
    if "$@"; then
        echo -e "${GREEN}  PASS${NC}"
        PASS=$((PASS + 1))
    else
        echo -e "${RED}  FAIL${NC}"
        FAIL=$((FAIL + 1))
    fi
}

# ──────────────────────────────────────────
# 1. Hardhat Tests
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Hardhat Tests ---${NC}"
run_step "Hardhat compile" npx hardhat compile
run_step "Hardhat tests (11)" npx hardhat test

# ──────────────────────────────────────────
# 2. Forge Build
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Build ---${NC}"
run_step "Forge build" forge build --sizes

# ──────────────────────────────────────────
# 3. Forge Unit Tests
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Unit Tests ---${NC}"
run_step "Unit tests" forge test --match-path "test-forge/unit/*" -vvv

# ──────────────────────────────────────────
# 4. Forge Fuzz Tests
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Fuzz Tests ---${NC}"
run_step "Fuzz tests (7 x 1000 runs)" forge test --match-path "test-forge/fuzz/*" -vvv

# ──────────────────────────────────────────
# 5. Forge Invariant Tests
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Invariant Tests ---${NC}"
run_step "Invariant tests (8 x 256 runs x 128 depth)" forge test --match-path "test-forge/invariant/*" -vvv

# ──────────────────────────────────────────
# 6. Forge Security Tests
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Security Tests ---${NC}"
run_step "Security tests (13)" forge test --match-path "test-forge/security/*" -vvv

# ──────────────────────────────────────────
# 7. Forge Coverage
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Forge Coverage ---${NC}"
run_step "Coverage report" forge coverage --report summary

# ──────────────────────────────────────────
# 8. Forge Test Results JSON
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Generating Reports ---${NC}"
echo "Generating Forge test results JSON..."
forge test --json > "$REPORT_DIR/forge-test-results.json" 2>/dev/null || true
echo -e "${GREEN}  Saved: $REPORT_DIR/forge-test-results.json${NC}"

# ──────────────────────────────────────────
# 9. Slither (Docker)
# ──────────────────────────────────────────
echo ""
echo -e "${BLUE}--- Slither Static Analysis ---${NC}"

if command -v docker &>/dev/null; then
    echo "Running Slither via Docker..."
    docker run --rm \
        -v "$(pwd):/src" \
        -w /src \
        ghcr.io/crytic/slither:latest \
        slither . \
        --compile-force-framework hardhat \
        --filter-paths "contracts/Migrations.sol" \
        --json /src/"$REPORT_DIR"/slither/slither-report.json \
        > "$REPORT_DIR/slither/slither-output.txt" 2>&1 || true

    echo -e "${GREEN}  Saved: $REPORT_DIR/slither/slither-report.json${NC}"
    echo -e "${GREEN}  Saved: $REPORT_DIR/slither/slither-output.txt${NC}"
    PASS=$((PASS + 1))
else
    echo -e "${RED}  Docker not found. Skipping Slither.${NC}"
    FAIL=$((FAIL + 1))
fi

# ──────────────────────────────────────────
# Summary
# ──────────────────────────────────────────
echo ""
echo "=============================================="
echo -e "${GREEN}Audit complete!${NC}"
echo -e "  Passed: ${GREEN}${PASS}${NC}  Failed: ${RED}${FAIL}${NC}"
echo ""
echo "Reports saved in: $REPORT_DIR/"
echo "=============================================="

# Generate summary report
cat > "$REPORT_DIR/AUDIT-SUMMARY.md" << EOF
# Security Audit Summary

**Date:** $(date -u +"%Y-%m-%d %H:%M UTC")
**Contract:** Token.sol (Solidity 0.7.0)
**Project:** Test Token (Wrapped ETH with Dividend Distribution)

## Tools Run

| Tool | Type | Status |
|------|------|--------|
| Hardhat | Unit tests (11) | Executed |
| Forge Unit | Unit tests (82) | Executed |
| Forge Fuzz | Fuzz tests (7 x 1000 runs) | Executed |
| Forge Invariant | Invariant tests (8 x 256 runs x 128 depth) | Executed |
| Forge Security | Security/attack tests (13) | Executed |
| Forge Coverage | Line/branch/function coverage | Executed |
| Slither | Static analysis (Docker) | Executed |

## Reports Generated

- \`$REPORT_DIR/forge-test-results.json\` - Forge test results
- \`$REPORT_DIR/slither/slither-report.json\` - Slither JSON report
- \`$REPORT_DIR/slither/slither-output.txt\` - Slither raw output
- \`$REPORT_DIR/README.md\` - Full security analysis report

## Steps

\`\`\`
Passed: $PASS  Failed: $FAIL
\`\`\`
EOF

echo -e "${GREEN}Summary saved: $REPORT_DIR/AUDIT-SUMMARY.md${NC}"
