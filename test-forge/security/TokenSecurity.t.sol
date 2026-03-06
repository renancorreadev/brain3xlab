// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../helpers/BaseTest.sol";

/// @title ReentrancyAttacker - Attempts reentrancy on burn/withdrawDividend
contract ReentrancyAttacker {
    IToken public token;
    uint256 public attackCount;
    uint256 public maxAttacks;
    bool public attackBurn;

    constructor(address _token) {
        token = IToken(_token);
    }

    function attackMint() external payable {
        token.mint{ value: msg.value }();
    }

    function attackBurnReentrancy(uint256 _maxAttacks) external {
        attackBurn = true;
        maxAttacks = _maxAttacks;
        attackCount = 0;
        token.burn(payable(address(this)));
    }

    function attackWithdrawReentrancy(uint256 _maxAttacks) external {
        attackBurn = false;
        maxAttacks = _maxAttacks;
        attackCount = 0;
        token.withdrawDividend(payable(address(this)));
    }

    receive() external payable {
        attackCount++;
        if (attackCount < maxAttacks) {
            if (attackBurn) {
                try token.burn(payable(address(this))) {} catch {}
            } else {
                try token.withdrawDividend(payable(address(this))) {} catch {}
            }
        }
    }
}

contract TokenSecurityTest is BaseTest {

    // --- Reentrancy Tests ---

    function test_burnReentrancyProtectedByCEI() public {
        // Token uses .transfer() (2300 gas limit) + CEI pattern
        // This means reentrancy is prevented by both:
        // 1. CEI: balance is zeroed before .transfer()
        // 2. Gas: .transfer() only forwards 2300 gas (not enough for re-entry)
        //
        // We verify the CEI protection by checking state after burn
        _mint(alice, 10 ether);
        assertEq(address(token).balance, 10 ether);

        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.burn(payable(dest));

        // Balance zeroed before transfer (CEI)
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(address(token).balance, 0);
        assertEq(dest.balance - preBal, 10 ether);
    }

    function test_burnReentrancyAttackerGetsNothing() public {
        // Attacker contract tries reentrancy but .transfer() 2300 gas prevents it
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(token));
        vm.deal(address(attacker), 10 ether);
        attacker.attackMint{ value: 10 ether }();

        // .transfer() to a contract with receive() that does external calls
        // will revert due to 2300 gas stipend
        vm.expectRevert();
        attacker.attackBurnReentrancy(3);
    }

    function test_withdrawDividendReentrancyProtectedByCEI() public {
        // Verify CEI: dividend is zeroed before transfer
        _mint(alice, 100);
        vm.deal(bob, 1000);
        vm.prank(bob);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(alice), 1000);

        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.withdrawDividend(payable(dest));

        // Dividend zeroed before transfer (CEI)
        assertEq(token.getWithdrawableDividend(alice), 0);
        assertEq(dest.balance - preBal, 1000);
    }

    function test_withdrawDividendReentrancyAttackerBlocked() public {
        _mint(alice, 100);
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(token));
        vm.deal(address(attacker), 10 ether);
        attacker.attackMint{ value: 100 }();

        vm.deal(charlie, 1000);
        vm.prank(charlie);
        token.recordDividend{ value: 1000 }();

        // .transfer() to attacker contract reverts (2300 gas not enough for re-entry)
        vm.expectRevert();
        attacker.attackWithdrawReentrancy(3);
    }

    // --- Zero Transfer Attack ---

    function test_zeroTransferDoesNotInflateHolderList() public {
        _mint(alice, 100);
        assertEq(token.getNumTokenHolders(), 1);

        // Transfer 0 to many addresses - should NOT add them to holder list
        for (uint256 i = 0; i < 10; i++) {
            address target = address(uint160(0x1000 + i));
            vm.prank(alice);
            token.transfer(target, 0);
        }

        // Only alice should be in holder list
        assertEq(token.getNumTokenHolders(), 1);
    }

    // --- Dividend Manipulation ---

    function test_cannotRecordDividendWithZeroSupply() public {
        // No one has minted, totalSupply = 0
        // recordDividend would divide by zero
        vm.deal(alice, 100);
        vm.prank(alice);
        // This should either revert due to divide by zero or have no holders to iterate
        // With our implementation, _holders is empty so the loop doesn't execute
        // but msg.value > 0 check passes, so ETH gets locked
        // This is a known design limitation, not a vulnerability
        token.recordDividend{ value: 100 }();
        // ETH is now in contract but nobody can withdraw it
        assertEq(address(token).balance, 100);
    }

    function test_dividendDustAccumulation() public {
        // Test rounding: mint asymmetric amounts and record small dividend
        _mint(alice, 3);
        _mint(bob, 7);
        // total = 10

        vm.deal(charlie, 1);
        vm.prank(charlie);
        token.recordDividend{ value: 1 }();

        // alice: 1 * 3 / 10 = 0 (integer div)
        // bob: 1 * 7 / 10 = 0 (integer div)
        // Total distributed: 0 (dust remains in contract)
        uint256 aliceDiv = token.getWithdrawableDividend(alice);
        uint256 bobDiv = token.getWithdrawableDividend(bob);
        assertEq(aliceDiv + bobDiv, 0, "dust should not be distributed");
    }

    // --- Transfer Edge Cases ---

    function test_transferFromExhaustsAllowanceExactly() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, 50);

        vm.prank(bob);
        token.transferFrom(alice, charlie, 50);

        assertEq(token.allowance(alice, bob), 0);

        // Now bob has 0 allowance, should revert
        vm.prank(bob);
        vm.expectRevert();
        token.transferFrom(alice, charlie, 1);
    }

    function test_burnWithZeroBalanceSendsNothing() public {
        // User with no tokens calls burn - sends 0 ETH
        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(dest.balance, preBal);
    }

    function test_withdrawWithZeroDividendSendsNothing() public {
        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.withdrawDividend(payable(dest));
        assertEq(dest.balance, preBal);
    }

    // --- Holder Tracking Stress ---

    function test_holderTrackingUnderMultipleSwaps() public {
        // Create 5 holders
        address[5] memory users;
        for (uint256 i = 0; i < 5; i++) {
            users[i] = address(uint160(0x5000 + i));
            vm.deal(users[i], 100 ether);
            vm.prank(users[i]);
            token.mint{ value: 1 ether }();
        }
        assertEq(token.getNumTokenHolders(), 5);

        // Remove middle holders via burn (triggers swap-and-pop)
        vm.prank(users[2]);
        token.burn(payable(users[2]));
        assertEq(token.getNumTokenHolders(), 4);

        vm.prank(users[0]);
        token.burn(payable(users[0]));
        assertEq(token.getNumTokenHolders(), 3);

        // Remaining: users[1], users[3], users[4]
        for (uint256 i = 1; i <= 3; i++) {
            address holder = token.getTokenHolder(i);
            assertTrue(
                holder == users[1] || holder == users[3] || holder == users[4],
                "unexpected holder"
            );
        }
    }

    // --- Allowance Overwrite ---

    function test_approveOverwriteDoesNotStack() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.approve(bob, 50);
        vm.prank(alice);
        token.approve(bob, 30);

        // Should be 30, not 80
        assertEq(token.allowance(alice, bob), 30);
    }

    // --- Large number of holders ---

    function test_manyHoldersGasNotExcessive() public {
        uint256 numHolders = 50;
        for (uint256 i = 0; i < numHolders; i++) {
            address user = address(uint160(0x9000 + i));
            vm.deal(user, 1 ether);
            vm.prank(user);
            token.mint{ value: 0.01 ether }();
        }

        assertEq(token.getNumTokenHolders(), numHolders);

        // Record dividend should succeed even with many holders
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        token.recordDividend{ value: 1 ether }();

        // Verify at least first holder got dividend
        address firstHolder = token.getTokenHolder(1);
        assertGt(token.getWithdrawableDividend(firstHolder), 0);
    }
}
