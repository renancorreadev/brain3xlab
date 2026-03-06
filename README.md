# Tech interview smart contracts coding problem

This is a Solidity coding problem for tech interviews. It is designed to take **no more than a few hours**.

## Getting setup

Ensure you have installed:

- [Node.js](https://nodejs.org/) **v20+**
- [Hardhat](https://hardhat.org/) (already included as a dev dependency)

## Instructions

### 1. Setup

Clone the repo locally and install the NPM dependencies using npm:

### 2. Task

**You only need to write code in the `Token.sol` file. Please ensure all the unit tests pass to successfully complete this part.**

The contracts consist of a mintable ERC-20 `Token` (which is similar to a _Wrapped ETH_ token). Callers mint tokens by depositing ETH. They can then burn their token balance to get the equivalent amount of deposited ETH back.

In addition, token holders can receive dividend payments in ETH in proportion to their token balance relative to the total supply. Dividends are assigned by looping through the list of holders.

Dividend payments are assigned to token holders' addresses. This means that even if a token holder were to send their tokens to somebody else later on or burn their tokens, they would still be entitled to the dividends they accrued whilst they were holding the tokens.

You will thus need to **efficiently** keep track of individual token holder addresses in order to assign dividend payouts to holders with minimal gas cost.

For a clearer understanding of how the code is supposed to work please refer to the tests in the `test` folder.

Your Solution must pass the test: `npm run test` - run the tests (Hardhat)

![Test Result](./test-result.png)

### 3: Submission

Record a short [Loom video](https://www.loom.com) showing how it works, including the expected and actual behavior if you're testing.

### 4. Deadline

Please complete and submit the result within 1 ~ 2 hours unless otherwise discussed.

---

# Security Analysis Report - Token.sol

**Project:** Test Token (Wrapped ETH with Dividend Distribution)
**Date:** 2026-03-06
**Solidity Version:** 0.7.0
**Tools Used:** Forge (unit, fuzz, invariant, security tests) + Slither (static analysis)

---

## Executive Summary

The Token.sol contract has been thoroughly analyzed using multiple security testing methodologies. **No exploitable vulnerabilities were found.** The contract implements proper security patterns including CEI (Checks-Effects-Interactions), SafeMath for arithmetic safety, and `.transfer()` for ETH sends (2300 gas limit prevents reentrancy).

| Metric | Result |
|---|---|
| **Token.sol Coverage** | 100% Lines, 100% Statements, 100% Branches, 100% Functions |
| **Total Tests** | 110 (82 unit + 7 fuzz + 8 invariant + 13 security) |
| **Fuzz Runs** | 7,000 (1,000 per fuzz test) |
| **Invariant Runs** | 2,048 (256 runs x 128 depth = 32,768 calls per invariant) |
| **Slither Findings** | 13 total, 0 exploitable |
| **Hardhat Tests** | 11/11 passing |

---

## Audit Summary

| Tool | Type | Status |
|------|------|--------|
| Hardhat | Unit tests (11) | Executed |
| Forge Unit | Unit tests (82) | Executed |
| Forge Fuzz | Fuzz tests (7 x 1000 runs) | Executed |
| Forge Invariant | Invariant tests (8 x 256 runs x 128 depth) | Executed |
| Forge Security | Security/attack tests (13) | Executed |
| Forge Coverage | Line/branch/function coverage | Executed |
| Slither | Static analysis (Docker) | Executed |

---

## Test Categories

### Unit Tests (82 tests)
Comprehensive function-level testing covering all public/external functions:

| Contract | Tests | Status |
|---|---|---|
| TokenDefaultsTest | 8 | PASS |
| TokenMintTest | 9 | PASS |
| TokenBurnTest | 7 | PASS |
| TokenTransferTest | 9 | PASS |
| TokenApproveAllowanceTest | 5 | PASS |
| TokenTransferFromTest | 9 | PASS |
| TokenHolderTrackingTest | 9 | PASS |
| TokenDividendRecordTest | 7 | PASS |
| TokenDividendCompoundTest | 2 | PASS |
| TokenDividendWithdrawalTest | 8 | PASS |
| TokenEdgeCasesTest | 8 | PASS |

### Fuzz Tests (7 tests x 1,000 runs each)
Property-based testing with randomized inputs:

| Test | Runs | Property |
|---|---|---|
| test_fuzz_mint | 1,000 | balance = minted amount, supply updates correctly |
| test_fuzz_mintAndBurn | 1,000 | mint then burn restores all balances to 0 |
| test_fuzz_transfer | 1,000 | transfer preserves total supply, updates balances |
| test_fuzz_approve | 1,000 | allowance set correctly for any amount |
| test_fuzz_transferFrom | 1,000 | transferFrom decrements allowance correctly |
| test_fuzz_dividendProportional | 1,000 | dividends proportional to holdings |
| test_fuzz_withdrawDividend | 1,000 | withdrawal sends correct amount, resets to 0 |

### Invariant Tests (8 invariants x 256 runs x 128 depth)
Stateful property testing with handler contract simulating random user actions:

| Invariant | Calls | Property |
|---|---|---|
| totalSupplyConsistency | 32,768 | totalSupply == sum(minted) - sum(burned) |
| ethBalanceGeTotalSupply | 32,768 | contract.balance >= totalSupply |
| holdersHaveNonZeroBalance | 32,768 | every tracked holder has balance > 0 |
| indexZeroReturnsNull | 32,768 | getTokenHolder(0) == address(0) |
| outOfBoundsReturnsNull | 32,768 | getTokenHolder(n+1) == address(0) |
| metadataImmutable | 32,768 | name, symbol, decimals never change |
| solvency | 32,768 | contract can always pay all obligations |
| callSummary | 32,768 | (logging invariant) |

### Security Tests (13 tests)
Attack vector and edge case testing:

| Test | Attack Vector | Result |
|---|---|---|
| burnReentrancyProtectedByCEI | Reentrancy via burn | PROTECTED (CEI + 2300 gas) |
| burnReentrancyAttackerBlocked | Reentrancy via malicious contract | BLOCKED (.transfer 2300 gas) |
| withdrawDividendReentrancyProtectedByCEI | Reentrancy via dividend withdrawal | PROTECTED (CEI + 2300 gas) |
| withdrawDividendReentrancyAttackerBlocked | Reentrancy via malicious contract | BLOCKED (.transfer 2300 gas) |
| zeroTransferDoesNotInflateHolderList | Holder list inflation via 0-transfers | PROTECTED |
| cannotRecordDividendWithZeroSupply | Dividend with 0 supply (div by zero) | No holders, ETH locked (known) |
| dividendDustAccumulation | Rounding dust from integer division | Expected behavior, documented |
| transferFromExhaustsAllowanceExactly | Allowance boundary testing | Correct behavior |
| burnWithZeroBalanceSendsNothing | Burn with 0 balance | No-op, correct |
| withdrawWithZeroDividendSendsNothing | Withdraw with 0 dividend | No-op, correct |
| holderTrackingUnderMultipleSwaps | Swap-and-pop correctness under stress | Correct O(1) removal |
| approveOverwriteDoesNotStack | Approve race condition | Overwrites, does not accumulate |
| manyHoldersGasNotExcessive | Gas limit with 50 holders | Acceptable gas usage |

---

## Security Properties Verified

### Reentrancy Protection
- **Mechanism:** CEI pattern + `.transfer()` (2300 gas stipend)
- **Verified:** Both `burn()` and `withdrawDividend()` zero state before external call
- **Verified:** Attacker contracts with `receive()` callbacks cannot re-enter

### Arithmetic Safety
- **Mechanism:** SafeMath library for all arithmetic operations
- **Verified:** Fuzz tests with random uint96 values found no overflow/underflow

### Holder Tracking Integrity
- **Mechanism:** Swap-and-pop array with 1-based index mapping
- **Verified:** 32,768 random operations maintained invariant: all holders have non-zero balance
- **Verified:** Zero-value transfers do not inflate holder list
- **Verified:** Multiple add/remove cycles maintain correct state

### Dividend Distribution Correctness
- **Mechanism:** Proportional distribution via `(msg.value * balance) / totalSupply`
- **Verified:** 1,000 fuzz runs with random amounts confirmed proportional distribution
- **Verified:** Dividends persist after burn/transfer (by design)
- **Verified:** Dividends compound correctly across multiple record calls
- **Known Limitation:** Integer division rounding leaves dust in contract (documented, non-exploitable)

### Solvency
- **Invariant:** `contract.balance >= totalSupply + recordedDividends - withdrawnDividends`
- **Verified:** 32,768 random operations never violated solvency

---

## Known Limitations (Non-Vulnerabilities)

1. **Rounding dust:** Integer division in `recordDividend()` leaves small amounts of unallocated ETH. This is inherent to EVM integer math and is common in all proportional distribution systems.

2. **Gas scaling:** `recordDividend()` iterates over all holders. With a very large holder set (1000+), this could approach block gas limit. For production, a pull-based dividend-per-share accumulator pattern is recommended.

3. **Zero-address destination:** `burn()` and `withdrawDividend()` accept `address(0)` as destination. Sending ETH to zero address burns it permanently. This is user error, not an exploit vector.

4. **Solidity 0.7.0:** Constrained by challenge rules. Known compiler bugs do not affect patterns used in Token.sol. SafeMath provides arithmetic safety.

---

# Slither Static Analysis Report

**Tool:** [Slither](https://github.com/crytic/slither) v0.10.x
**Contracts Analyzed:** 6 (Token.sol, Migrations.sol, IERC20.sol, IMintableToken.sol, IDividends.sol, SafeMath.sol)
**Detectors Run:** 101

---

## Slither Executive Summary

Slither identified **13 findings** across 7 detector categories in 6 contracts. After contextual analysis, **0 findings represent exploitable vulnerabilities** in the Token.sol contract. The single High-severity finding is a **false positive** given the contract's dividend distribution design. All other findings are either Low/Informational severity, related to the legacy Migrations.sol contract (not part of the project), or are optimization suggestions blocked by challenge constraints.

| Severity | Count | Real Issues | False Positives / Accepted |
|---|---|---|---|
| **High** | 1 | 0 | 1 |
| **Medium** | 0 | 0 | 0 |
| **Low** | 3 | 0 | 3 |
| **Informational** | 5 | 0 | 5 |
| **Optimization** | 4 | 0 | 4 |
| **Total** | **13** | **0** | **13** |

---

## Findings Summary Table

| ID | Detector | Impact | Confidence | Description | File:Line | Status |
|---|---|---|---|---|---|---|
| ID-0 | `msg-value-loop` | **High** | Medium | `msg.value` used inside a loop in `recordDividend()` | `Token.sol:195-206` | False Positive -- By Design |
| ID-1 | `missing-zero-check` | Low | Medium | `burn(address)` - `dest` param lacks zero-address check | `Token.sol:164` | Accepted Risk |
| ID-2 | `missing-zero-check` | Low | Medium | `withdrawDividend(address)` - `dest` param lacks zero-address check | `Token.sol:215` | Accepted Risk |
| ID-3 | `incorrect-modifier` | Low | High | `Migrations.restricted()` does not always execute `_;` or revert | `Migrations.sol:7-9` | Not Applicable (Legacy) |
| ID-4 | `solc-version` | Informational | High | solc-0.7.0 is outdated; recommends >= 0.8.0 | N/A | Acknowledged -- Constrained |
| ID-5 | `solc-version` | Informational | High | Solidity 0.7.0 has known compiler bugs | `Migrations.sol:1` | Acknowledged -- Constrained |
| ID-6 | `solc-version` | Informational | High | Solidity 0.7.0 has known compiler bugs (Token.sol and interfaces) | `Token.sol:1` | Acknowledged -- Constrained |
| ID-7 | `naming-convention` | Informational | High | `last_completed_migration` is not in mixedCase | `Migrations.sol:5` | Not Applicable (Legacy) |
| ID-8 | `naming-convention` | Informational | High | `new_address` param is not in mixedCase | `Migrations.sol:19` | Not Applicable (Legacy) |
| ID-9 | `constable-states` | Optimization | High | `Token.decimals` should be `constant` | `Token.sol:17` | Cannot Fix -- DO NOT EDIT |
| ID-10 | `constable-states` | Optimization | High | `Token.symbol` should be `constant` | `Token.sol:19` | Cannot Fix -- DO NOT EDIT |
| ID-11 | `constable-states` | Optimization | High | `Token.name` should be `constant` | `Token.sol:18` | Cannot Fix -- DO NOT EDIT |
| ID-12 | `immutable-states` | Optimization | High | `Migrations.owner` should be `immutable` | `Migrations.sol:4` | Not Applicable (Legacy) |

---

## Detailed Analysis

### ID-0: msg-value-loop (HIGH)

**Detector:** `msg-value-loop`
**Impact:** High | **Confidence:** Medium
**Location:** `contracts/Token.sol#195-206`

**Description:**
Slither flags the use of `msg.value` inside a `for` loop in `Token.recordDividend()`. The concern behind this detector is that in functions handling multiple calls or delegations, `msg.value` could be re-used across iterations, leading to an attacker spending the same ETH multiple times (a well-known vulnerability in batch-processing payable functions).

**Relevant Code:**
```solidity
function recordDividend() external payable override requireETH {
    uint256 supply = totalSupply;
    uint256 len = _holders.length;

    for (uint256 i = 0; i < len; i++) {
        address holder = _holders[i];
        uint256 share = msg.value.mul(balanceOf[holder]).div(supply);
        _withdrawableDividend[holder] = _withdrawableDividend[holder].add(share);
    }

    emit DividendRecorded(msg.sender, msg.value);
}
```

**Analysis: FALSE POSITIVE -- By Design**

This is a textbook false positive. The `msg-value-loop` detector is designed to catch cases where `msg.value` is used as the *amount to transfer* inside a loop (e.g., sending `msg.value` ETH to each recipient, effectively multiplying the spend). In this contract:

1. **No ETH is sent in the loop.** The loop only *reads* `msg.value` to compute each holder's proportional share. It performs arithmetic, not transfers.
2. **The math is correct.** Each holder receives `msg.value * balanceOf[holder] / totalSupply`, which sums to at most `msg.value` (with minor dust due to integer division).
3. **This is the intended dividend distribution mechanism.** A single ETH deposit is split proportionally among all holders -- reading `msg.value` in each iteration is the correct and expected behavior.
4. **No double-spend risk.** The ETH is received once by the contract and stays in the contract balance. Holders withdraw their share later via `withdrawDividend()`.

**Verdict:** Not exploitable. No action required.

---

### ID-1: missing-zero-check on burn(address).dest (LOW)

**Detector:** `missing-zero-check`
**Impact:** Low | **Confidence:** Medium
**Location:** `contracts/Token.sol#164`

**Description:**
The `burn(address payable dest)` function does not validate that `dest != address(0)` before calling `dest.transfer(amount)`.

**Relevant Code:**
```solidity
function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);
    emit Burn(msg.sender, dest, amount);
    dest.transfer(amount);
}
```

**Analysis: Accepted Risk**

- Sending ETH to `address(0)` via `.transfer()` would permanently burn the ETH.
- However, this is a **user error**, not an exploitable vulnerability. The caller explicitly provides the destination address. No third party can force a user to burn to `address(0)`.
- Adding a `require(dest != address(0))` check would be a minor defensive improvement but is not a security vulnerability.

**Verdict:** Low risk -- user is responsible for providing a valid destination.

---

### ID-2: missing-zero-check on withdrawDividend(address).dest (LOW)

**Detector:** `missing-zero-check`
**Impact:** Low | **Confidence:** Medium
**Location:** `contracts/Token.sol#215`

**Description:**
The `withdrawDividend(address payable dest)` function does not validate that `dest != address(0)` before calling `dest.transfer(amount)`.

**Analysis: Accepted Risk**

Same reasoning as ID-1. The caller explicitly chooses the destination. Sending dividends to `address(0)` is a user mistake, not an exploit vector. The contract correctly follows the Checks-Effects-Interactions (CEI) pattern, zeroing the dividend balance before the external call, which prevents reentrancy.

**Verdict:** Low risk -- same as ID-1.

---

### ID-3: incorrect-modifier in Migrations.restricted() (LOW)

**Detector:** `incorrect-modifier`
**Impact:** Low | **Confidence:** High
**Location:** `contracts/Migrations.sol#7-9`

**Description:**
The `restricted()` modifier uses an `if` statement instead of `require`, meaning that if `msg.sender != owner`, the function body simply does not execute (silently succeeds without reverting).

**Analysis: Not Applicable**

This is a genuine code quality issue but **Migrations.sol is a legacy Truffle framework contract** and is not part of the Token project's business logic.

**Verdict:** Not applicable to the project's security posture.

---

### ID-4 / ID-5 / ID-6: solc-version (INFORMATIONAL)

**Detector:** `solc-version`
**Impact:** Informational | **Confidence:** High

**Description:**
Solidity 0.7.0 is outdated and has known compiler bugs. Slither recommends upgrading to at least Solidity 0.8.0 for built-in overflow/underflow protection.

**Analysis: Acknowledged -- Cannot Change**

The Solidity version is **constrained to 0.7.0 by challenge rules**. The contract mitigates the lack of built-in overflow protection by using **SafeMath** for all arithmetic operations. None of the listed known compiler bugs affect the patterns used in Token.sol.

**Verdict:** Constrained by project requirements. SafeMath usage provides adequate arithmetic safety.

---

### ID-7 / ID-8: naming-convention (INFORMATIONAL)

**Detector:** `naming-convention`

**Description:** Variables in Migrations.sol use `snake_case` instead of `mixedCase`.

**Verdict:** Not applicable. Legacy Truffle contract.

---

### ID-9 / ID-10 / ID-11: constable-states (OPTIMIZATION)

**Detector:** `constable-states`
**Location:** `contracts/Token.sol#17-19`

**Description:**
The state variables `decimals`, `name`, and `symbol` should be declared as `constant` to save gas (~2100 gas per SLOAD).

**Analysis: Cannot Fix -- DO NOT EDIT Section**

These variables are located within the **"DO NOT EDIT THIS SECTION"** block mandated by the challenge rules.

**Verdict:** Valid optimization but cannot be applied due to challenge constraints.

---

### ID-12: immutable-states (OPTIMIZATION)

**Detector:** `immutable-states`
**Location:** `contracts/Migrations.sol#4`

**Description:** `Migrations.owner` could be declared `immutable`.

**Verdict:** Not applicable. Legacy Truffle contract.

---

## Token.sol Specific Assessment

### Are the findings real vulnerabilities?

| Finding | Real Vulnerability? | Explanation |
|---|---|---|
| `msg-value-loop` in `recordDividend()` | **No** | Correct implementation of proportional dividend distribution. `msg.value` is read (not spent) in each iteration. |
| Missing zero-check in `burn()` | **No** | User-initiated action; the caller chooses the destination. |
| Missing zero-check in `withdrawDividend()` | **No** | Same as above. |
| `decimals`/`name`/`symbol` not `constant` | **No** | Gas optimization only. Blocked by "DO NOT EDIT" section. |

### Design Choices Validated

1. **CEI Pattern:** Both `burn()` and `withdrawDividend()` correctly implement Checks-Effects-Interactions -- state is modified before external calls, preventing reentrancy attacks.

2. **SafeMath Usage:** All arithmetic uses SafeMath's `.add()`, `.sub()`, `.mul()`, and `.div()`, providing overflow/underflow protection that compensates for the absence of Solidity 0.8.x built-in checks.

3. **Holder Tracking:** The swap-and-pop pattern in `_removeHolder()` provides O(1) removal, which is an efficient and correct data structure choice.

4. **Dividend Distribution:** The `recordDividend()` loop is an intentional design pattern. The minor dust (wei lost to integer division rounding) is an accepted trade-off common in all proportional distribution systems on the EVM.

---

## Recommendations

### Priority 1 -- Consider If Rules Allow

| # | Recommendation | Severity | Effort |
|---|---|---|---|
| 1 | Add `require(dest != address(0))` to `burn()` | Low | Trivial |
| 2 | Add `require(dest != address(0))` to `withdrawDividend()` | Low | Trivial |

### Priority 2 -- Acknowledged Constraints (No Action Possible)

| # | Item | Reason |
|---|---|---|
| 3 | Upgrade Solidity to >= 0.8.0 | Blocked by challenge rules (version pinned to 0.7.0) |
| 4 | Make `decimals`, `name`, `symbol` constant | Blocked by "DO NOT EDIT" section |

### Additional Observations (Not Flagged by Slither)

- **Gas Concern:** `recordDividend()` iterates over all holders. If the holder set grows very large, this function could exceed the block gas limit. Consider implementing a pull-based dividend pattern for production use.
- **Rounding Dust:** Integer division in `msg.value * balance / supply` will leave small amounts of ETH unallocated in the contract. Over many dividend distributions, this dust accumulates and becomes permanently locked.

---

## Conclusion

The Slither analysis of the Token.sol contract reveals **no exploitable vulnerabilities**. The single High-severity finding (`msg-value-loop`) is a false positive -- the contract reads `msg.value` for arithmetic, not for sending ETH, and the dividend distribution logic is correct by design. All Low-severity findings are user-responsibility issues (missing zero-address checks), and all Informational/Optimization findings are either constrained by challenge rules or relate to the out-of-scope Migrations.sol legacy contract.

The contract demonstrates solid security practices including the CEI pattern, SafeMath usage, and efficient data structures.

---

*Generated from Forge test suite (110 tests) and Slither static analysis (101 detectors). Token.sol: 100% code coverage.*
