// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../helpers/BaseTest.sol";
import "./handlers/TokenHandler.sol";

/// @title TokenInvariantTest - Stateful invariant tests using handler
/// @dev Forge calls random handler functions and checks invariants after each call
contract TokenInvariantTest is BaseTest {
    TokenHandler internal handler;

    function setUp() public override {
        super.setUp();
        handler = new TokenHandler(token);

        // Tell Forge to only call the handler
        targetContract(address(handler));
    }

    /// @dev Total supply must equal minted - burned
    function invariant_totalSupplyConsistency() public view {
        assertEq(
            token.totalSupply(),
            handler.ghost_totalMinted() - handler.ghost_totalBurned(),
            "totalSupply != minted - burned"
        );
    }

    /// @dev Contract ETH balance >= totalSupply (dividends add extra)
    function invariant_ethBalanceGeTotalSupply() public view {
        assertGe(
            address(token).balance,
            token.totalSupply(),
            "ETH balance < totalSupply"
        );
    }

    /// @dev Every reported holder has non-zero balance
    function invariant_holdersHaveNonZeroBalance() public view {
        uint256 n = token.getNumTokenHolders();
        for (uint256 i = 1; i <= n; i++) {
            address holder = token.getTokenHolder(i);
            assertNotEq(holder, address(0), "holder is zero address");
            assertGt(token.balanceOf(holder), 0, "holder has zero balance");
        }
    }

    /// @dev getTokenHolder(0) always returns address(0)
    function invariant_indexZeroReturnsNull() public view {
        assertEq(token.getTokenHolder(0), address(0));
    }

    /// @dev Out-of-bounds index returns address(0)
    function invariant_outOfBoundsReturnsNull() public view {
        uint256 n = token.getNumTokenHolders();
        assertEq(token.getTokenHolder(n + 1), address(0));
    }

    /// @dev Immutable metadata
    function invariant_metadataImmutable() public view {
        assertEq(token.name(), "Test token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.decimals(), 18);
    }

    /// @dev Contract solvency: ETH balance >= totalSupply + pending dividends - withdrawn
    function invariant_solvency() public view {
        uint256 contractBal = address(token).balance;
        uint256 totalDivRecorded = handler.ghost_totalDividendsRecorded();
        uint256 totalDivWithdrawn = handler.ghost_totalDividendsWithdrawn();
        uint256 expectedMin = token.totalSupply() + totalDivRecorded - totalDivWithdrawn;
        assertGe(contractBal, expectedMin, "contract is insolvent");
    }

    /// @dev Ghost summary for debugging
    function invariant_callSummary() public view {
        // This invariant always passes; it's just for logging
        handler.ghost_mintCalls();
        handler.ghost_burnCalls();
        handler.ghost_transferCalls();
        handler.ghost_dividendCalls();
    }
}
