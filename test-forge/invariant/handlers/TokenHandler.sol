// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../interfaces/IToken.sol";

/// @title TokenHandler - Invariant test handler that simulates user actions
/// @dev Forge calls random functions on this handler to explore state space
contract TokenHandler is Test {
    IToken public token;

    address[] public actors;
    address internal currentActor;

    // Ghost variables for tracking
    uint256 public ghost_totalMinted;
    uint256 public ghost_totalBurned;
    uint256 public ghost_totalDividendsRecorded;
    uint256 public ghost_totalDividendsWithdrawn;
    uint256 public ghost_mintCalls;
    uint256 public ghost_burnCalls;
    uint256 public ghost_transferCalls;
    uint256 public ghost_dividendCalls;

    modifier useActor(uint256 seed) {
        currentActor = actors[seed % actors.length];
        vm.startPrank(currentActor);
        _;
        vm.stopPrank();
    }

    constructor(IToken _token) {
        token = _token;
        actors.push(makeAddr("actor0"));
        actors.push(makeAddr("actor1"));
        actors.push(makeAddr("actor2"));
        actors.push(makeAddr("actor3"));

        for (uint256 i = 0; i < actors.length; i++) {
            vm.deal(actors[i], 100 ether);
        }
    }

    function mint(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        amount = bound(amount, 1, 10 ether);
        if (currentActor.balance < amount) return;

        token.mint{ value: amount }();
        ghost_totalMinted += amount;
        ghost_mintCalls++;
    }

    function burn(uint256 actorSeed) external useActor(actorSeed) {
        uint256 bal = token.balanceOf(currentActor);
        if (bal == 0) return;

        address payable dest = payable(currentActor);
        token.burn(dest);
        ghost_totalBurned += bal;
        ghost_burnCalls++;
    }

    function transfer(uint256 actorSeed, uint256 toSeed, uint256 amount) external useActor(actorSeed) {
        uint256 bal = token.balanceOf(currentActor);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);

        address to = actors[toSeed % actors.length];
        token.transfer(to, amount);
        ghost_transferCalls++;
    }

    function approve(uint256 actorSeed, uint256 spenderSeed, uint256 amount) external useActor(actorSeed) {
        address spender = actors[spenderSeed % actors.length];
        amount = bound(amount, 0, type(uint128).max);
        token.approve(spender, amount);
    }

    function transferFrom(uint256 actorSeed, uint256 fromSeed, uint256 toSeed, uint256 amount) external useActor(actorSeed) {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        uint256 allowance = token.allowance(from, currentActor);
        uint256 bal = token.balanceOf(from);
        uint256 maxTransfer = allowance < bal ? allowance : bal;
        if (maxTransfer == 0) return;
        amount = bound(amount, 1, maxTransfer);

        token.transferFrom(from, to, amount);
        ghost_transferCalls++;
    }

    function recordDividend(uint256 actorSeed, uint256 amount) external useActor(actorSeed) {
        if (token.totalSupply() == 0) return;
        amount = bound(amount, 1, 5 ether);
        if (currentActor.balance < amount) return;

        token.recordDividend{ value: amount }();
        ghost_totalDividendsRecorded += amount;
        ghost_dividendCalls++;
    }

    function withdrawDividend(uint256 actorSeed) external useActor(actorSeed) {
        uint256 dividend = token.getWithdrawableDividend(currentActor);
        if (dividend == 0) return;

        address payable dest = payable(currentActor);
        token.withdrawDividend(dest);
        ghost_totalDividendsWithdrawn += dividend;
    }
}
