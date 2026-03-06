// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../helpers/BaseTest.sol";

contract TokenDefaultsTest is BaseTest {
    function test_name() public view {
        assertEq(token.name(), "Test token");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "TEST");
    }

    function test_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_initialTotalSupply() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_initialBalanceIsZero() public view {
        assertEq(token.balanceOf(alice), 0);
    }

    function test_initialHolderCountIsZero() public view {
        assertEq(token.getNumTokenHolders(), 0);
    }

    function test_initialAllowanceIsZero() public view {
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_initialWithdrawableDividendIsZero() public view {
        assertEq(token.getWithdrawableDividend(alice), 0);
    }
}

contract TokenMintTest is BaseTest {
    function test_mintRevertsWithZeroValue() public {
        vm.prank(alice);
        vm.expectRevert("Token: must send ETH");
        token.mint();
    }

    function test_mintRevertsWithZeroValueExplicit() public {
        vm.prank(alice);
        vm.expectRevert("Token: must send ETH");
        token.mint{ value: 0 }();
    }

    function test_mintCreatesTokens() public {
        _mint(alice, 100);
        assertEq(token.balanceOf(alice), 100);
        assertEq(token.totalSupply(), 100);
    }

    function test_mintAccumulatesBalance() public {
        _mint(alice, 50);
        _mint(alice, 30);
        assertEq(token.balanceOf(alice), 80);
        assertEq(token.totalSupply(), 80);
    }

    function test_mintMultipleAccounts() public {
        _mint(alice, 50);
        _mint(bob, 70);
        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(bob), 70);
        assertEq(token.totalSupply(), 120);
    }

    function test_mintDepositsETHInContract() public {
        _mint(alice, 100);
        assertEq(address(token).balance, 100);
    }

    function test_mintAddsToHolderList() public {
        _mint(alice, 50);
        assertEq(token.getNumTokenHolders(), 1);
        assertEq(token.getTokenHolder(1), alice);
    }

    function test_mintMultipleHolders() public {
        _mint(alice, 50);
        _mint(bob, 50);
        assertEq(token.getNumTokenHolders(), 2);

        address[] memory expected = new address[](2);
        expected[0] = alice;
        expected[1] = bob;
        _assertHolders(expected);
    }

    function test_mintDoesNotDuplicateHolder() public {
        _mint(alice, 50);
        _mint(alice, 50);
        assertEq(token.getNumTokenHolders(), 1);
    }
}

contract TokenBurnTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 100);
        _mint(bob, 50);
    }

    function test_burnSendsETHToDest() public {
        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(dest.balance - preBal, 100);
    }

    function test_burnZerosBalance() public {
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.balanceOf(alice), 0);
    }

    function test_burnDecreasesTotalSupply() public {
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.totalSupply(), 50);
    }

    function test_burnRemovesFromHolderList() public {
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.getNumTokenHolders(), 1);
        assertEq(token.getTokenHolder(1), bob);
    }

    function test_burnWithZeroBalance() public {
        // Charlie has no tokens - burn sends 0 ETH
        uint256 preBal = dest.balance;
        vm.prank(charlie);
        token.burn(payable(dest));
        assertEq(dest.balance, preBal);
    }

    function test_burnReducesContractBalance() public {
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(address(token).balance, 50);
    }

    function test_burnAllHolders() public {
        vm.prank(alice);
        token.burn(payable(dest));
        vm.prank(bob);
        token.burn(payable(dest));
        assertEq(token.getNumTokenHolders(), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(address(token).balance, 0);
    }
}

contract TokenTransferTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 100);
        _mint(bob, 50);
    }

    function test_transferMovesTokens() public {
        vm.prank(alice);
        token.transfer(charlie, 30);
        assertEq(token.balanceOf(alice), 70);
        assertEq(token.balanceOf(charlie), 30);
    }

    function test_transferDoesNotChangeTotalSupply() public {
        vm.prank(alice);
        token.transfer(charlie, 30);
        assertEq(token.totalSupply(), 150);
    }

    function test_transferRevertsOnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert("Token: insufficient balance");
        token.transfer(charlie, 101);
    }

    function test_transferAddsRecipientToHolderList() public {
        vm.prank(alice);
        token.transfer(charlie, 30);
        assertEq(token.getNumTokenHolders(), 3);
    }

    function test_transferRemovesSenderIfZeroBalance() public {
        vm.prank(alice);
        token.transfer(charlie, 100);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.getNumTokenHolders(), 2);

        address[] memory expected = new address[](2);
        expected[0] = bob;
        expected[1] = charlie;
        _assertHolders(expected);
    }

    function test_transferZeroDoesNotAddToHolderList() public {
        vm.prank(alice);
        token.transfer(charlie, 0);
        // Charlie should NOT be in holder list
        assertEq(token.getNumTokenHolders(), 2);
        assertEq(token.balanceOf(charlie), 0);
    }

    function test_transferToSelf() public {
        vm.prank(alice);
        token.transfer(alice, 50);
        assertEq(token.balanceOf(alice), 100);
        assertEq(token.getNumTokenHolders(), 2);
    }

    function test_transferEntireBalance() public {
        vm.prank(alice);
        token.transfer(bob, 100);
        assertEq(token.balanceOf(alice), 0);
        assertEq(token.balanceOf(bob), 150);
        assertEq(token.getNumTokenHolders(), 1);
    }

    function test_transferReturnsTrue() public {
        vm.prank(alice);
        bool result = token.transfer(bob, 10);
        assertTrue(result);
    }
}

contract TokenApproveAllowanceTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 100);
        _mint(bob, 50);
    }

    function test_approveSetAllowance() public {
        vm.prank(alice);
        token.approve(bob, 50);
        assertEq(token.allowance(alice, bob), 50);
    }

    function test_approveOverwritesPrevious() public {
        vm.prank(alice);
        token.approve(bob, 50);
        vm.prank(alice);
        token.approve(bob, 30);
        assertEq(token.allowance(alice, bob), 30);
    }

    function test_approveToZero() public {
        vm.prank(alice);
        token.approve(bob, 50);
        vm.prank(alice);
        token.approve(bob, 0);
        assertEq(token.allowance(alice, bob), 0);
    }

    function test_approveReturnsTrue() public {
        vm.prank(alice);
        bool result = token.approve(bob, 10);
        assertTrue(result);
    }

    function test_approveDoesNotAffectBalance() public {
        vm.prank(alice);
        token.approve(bob, 50);
        assertEq(token.balanceOf(alice), 100);
        assertEq(token.balanceOf(bob), 50);
    }
}

contract TokenTransferFromTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 100);
        _mint(bob, 50);
        vm.prank(alice);
        token.approve(bob, 40);
    }

    function test_transferFromMovesTokens() public {
        vm.prank(bob);
        token.transferFrom(alice, charlie, 30);
        assertEq(token.balanceOf(alice), 70);
        assertEq(token.balanceOf(charlie), 30);
    }

    function test_transferFromDecrementsAllowance() public {
        vm.prank(bob);
        token.transferFrom(alice, charlie, 30);
        assertEq(token.allowance(alice, bob), 10);
    }

    function test_transferFromRevertsOnInsufficientAllowance() public {
        vm.prank(bob);
        vm.expectRevert("Token: insufficient allowance");
        token.transferFrom(alice, charlie, 41);
    }

    function test_transferFromRevertsOnInsufficientBalance() public {
        // Give bob a huge allowance but alice only has 100
        vm.prank(alice);
        token.approve(bob, 200);
        vm.prank(bob);
        vm.expectRevert("Token: insufficient balance");
        token.transferFrom(alice, charlie, 101);
    }

    function test_transferFromExactAllowance() public {
        vm.prank(bob);
        token.transferFrom(alice, charlie, 40);
        assertEq(token.allowance(alice, bob), 0);
        assertEq(token.balanceOf(charlie), 40);
    }

    function test_transferFromAddsRecipientToHolders() public {
        vm.prank(bob);
        token.transferFrom(alice, charlie, 10);
        assertEq(token.getNumTokenHolders(), 3);
    }

    function test_transferFromRemovesSenderIfZeroBalance() public {
        vm.prank(alice);
        token.approve(bob, 100);
        vm.prank(bob);
        token.transferFrom(alice, charlie, 100);
        assertEq(token.balanceOf(alice), 0);

        address[] memory expected = new address[](2);
        expected[0] = bob;
        expected[1] = charlie;
        _assertHolders(expected);
    }

    function test_transferFromZeroDoesNotAddRecipient() public {
        vm.prank(bob);
        token.transferFrom(alice, charlie, 0);
        assertEq(token.getNumTokenHolders(), 2);
    }

    function test_transferFromReturnsTrue() public {
        vm.prank(bob);
        bool result = token.transferFrom(alice, charlie, 10);
        assertTrue(result);
    }
}

contract TokenHolderTrackingTest is BaseTest {
    function test_getTokenHolderReturnsZeroForIndexZero() public view {
        assertEq(token.getTokenHolder(0), address(0));
    }

    function test_getTokenHolderReturnsZeroForOutOfBounds() public {
        _mint(alice, 50);
        assertEq(token.getTokenHolder(2), address(0));
        assertEq(token.getTokenHolder(100), address(0));
    }

    function test_getTokenHolderOneBased() public {
        _mint(alice, 50);
        _mint(bob, 50);
        // Index 1 and 2 should return holders, 0 and 3 should return address(0)
        assertEq(token.getTokenHolder(0), address(0));
        assertTrue(token.getTokenHolder(1) != address(0));
        assertTrue(token.getTokenHolder(2) != address(0));
        assertEq(token.getTokenHolder(3), address(0));
    }

    function test_holderRemovedOnFullTransfer() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.transfer(bob, 100);
        assertEq(token.getNumTokenHolders(), 1);
        assertEq(token.getTokenHolder(1), bob);
    }

    function test_holderRemovedOnBurn() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.getNumTokenHolders(), 0);
    }

    function test_holderNotRemovedOnPartialTransfer() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.transfer(bob, 50);
        assertEq(token.getNumTokenHolders(), 2);
    }

    function test_holderSwapAndPopCorrectness() public {
        // Mint for alice, bob, charlie
        _mint(alice, 50);
        _mint(bob, 50);
        _mint(charlie, 50);
        assertEq(token.getNumTokenHolders(), 3);

        // Remove bob (middle element) - should swap with charlie
        vm.prank(bob);
        token.burn(payable(dest));
        assertEq(token.getNumTokenHolders(), 2);

        address[] memory expected = new address[](2);
        expected[0] = alice;
        expected[1] = charlie;
        _assertHolders(expected);
    }

    function test_holderReaddedAfterBurnAndMint() public {
        _mint(alice, 50);
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.getNumTokenHolders(), 0);

        _mint(alice, 100);
        assertEq(token.getNumTokenHolders(), 1);
        assertEq(token.getTokenHolder(1), alice);
    }

    function test_holderTrackingAfterMintBurnTransfer() public {
        _mint(alice, 50);
        _mint(bob, 50);
        _mint(charlie, 100);
        vm.prank(alice);
        token.burn(payable(dest));

        assertEq(token.getNumTokenHolders(), 2);
        address[] memory expected = new address[](2);
        expected[0] = bob;
        expected[1] = charlie;
        _assertHolders(expected);
    }
}

contract TokenDividendRecordTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 50);
        _mint(bob, 50);
    }

    function test_recordDividendRevertsWithZeroValue() public {
        vm.expectRevert("Token: must send ETH");
        token.recordDividend();
    }

    function test_recordDividendRevertsWithZeroValueExplicit() public {
        vm.expectRevert("Token: must send ETH");
        token.recordDividend{ value: 0 }();
    }

    function test_recordDividendEqualDistribution() public {
        vm.deal(dave, 1000);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(alice), 500);
        assertEq(token.getWithdrawableDividend(bob), 500);
    }

    function test_recordDividendProportionalDistribution() public {
        // alice: 50, bob: 50, charlie: 100 => total 200
        _mint(charlie, 100);
        vm.deal(dave, 1000);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(alice), 250);   // 50/200 * 1000
        assertEq(token.getWithdrawableDividend(bob), 250);     // 50/200 * 1000
        assertEq(token.getWithdrawableDividend(charlie), 500); // 100/200 * 1000
    }

    function test_recordDividendOnlyCurrentHolders() public {
        // Burn alice's tokens, then record dividend
        vm.prank(alice);
        token.burn(payable(dest));

        vm.deal(dave, 1000);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(alice), 0);
        assertEq(token.getWithdrawableDividend(bob), 1000);
    }

    function test_recordDividendNonHolderGetsZero() public {
        vm.deal(dave, 1000);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(charlie), 0);
    }

    function test_recordDividendFromAnyAddress() public {
        // Anyone can call recordDividend, not just holders
        vm.deal(dave, 500);
        vm.prank(dave);
        token.recordDividend{ value: 500 }();
        assertEq(token.getWithdrawableDividend(alice), 250);
    }
}

contract TokenDividendCompoundTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 50);
        _mint(bob, 50);
    }

    function test_dividendsAccumulate() public {
        vm.deal(dave, 2000);

        vm.prank(dave);
        token.recordDividend{ value: 1000 }();
        assertEq(token.getWithdrawableDividend(alice), 500);

        vm.prank(dave);
        token.recordDividend{ value: 1000 }();
        assertEq(token.getWithdrawableDividend(alice), 1000);
    }

    function test_dividendsCompoundAfterProportionChange() public {
        // Transfer to change proportions
        vm.prank(alice);
        token.transfer(charlie, 25);

        // alice: 25, bob: 50, charlie: 25 => total 100
        vm.deal(dave, 2000);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();

        assertEq(token.getWithdrawableDividend(alice), 250);
        assertEq(token.getWithdrawableDividend(bob), 500);
        assertEq(token.getWithdrawableDividend(charlie), 250);

        // Now change proportions again
        vm.prank(bob);
        token.transfer(charlie, 25);
        _mint(bob, 75);
        vm.prank(alice);
        token.burn(payable(alice)); // burn sends ETH back to alice

        // alice: 0, bob: 100, charlie: 50 => total 150
        vm.prank(dave);
        token.recordDividend{ value: 90 }();

        // Previous + new
        assertEq(token.getWithdrawableDividend(alice), 250 + 0);
        assertEq(token.getWithdrawableDividend(bob), 500 + 60);   // 100/150 * 90 = 60
        assertEq(token.getWithdrawableDividend(charlie), 250 + 30); // 50/150 * 90 = 30
    }
}

contract TokenDividendWithdrawalTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _mint(alice, 50);
        _mint(bob, 50);
        vm.prank(alice);
        token.transfer(charlie, 25);
        // alice: 25, bob: 50, charlie: 25

        vm.deal(dave, 10000 ether);
        vm.prank(dave);
        token.recordDividend{ value: 1000 }();
    }

    function test_withdrawSendsETHToDest() public {
        uint256 preBal = dest.balance;
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        assertEq(dest.balance - preBal, 500);
    }

    function test_withdrawResetsBalance() public {
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        assertEq(token.getWithdrawableDividend(bob), 0);
    }

    function test_withdrawDoesNotAffectOthers() public {
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        assertEq(token.getWithdrawableDividend(alice), 250);
        assertEq(token.getWithdrawableDividend(charlie), 250);
    }

    function test_withdrawZeroDividend() public {
        // Dave has no dividend
        uint256 preBal = dest.balance;
        vm.prank(dave);
        token.withdrawDividend(payable(dest));
        assertEq(dest.balance, preBal);
    }

    function test_doubleWithdrawGetsZeroSecondTime() public {
        vm.prank(bob);
        token.withdrawDividend(payable(dest));

        uint256 preBal = dest.balance;
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        assertEq(dest.balance, preBal);
    }

    function test_withdrawAfterBurnPreservesDividend() public {
        // Bob burns tokens but dividend persists
        vm.prank(bob);
        token.burn(payable(dest));

        // Bob still has 500 dividend
        assertEq(token.getWithdrawableDividend(bob), 500);

        uint256 preBal = dest.balance;
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        // burn sent 50 already, now withdraw sends 500
        assertEq(dest.balance - preBal, 500);
    }

    function test_withdrawBetweenPayouts() public {
        // Bob withdraws his 500
        vm.prank(bob);
        token.withdrawDividend(payable(dest));
        assertEq(token.getWithdrawableDividend(bob), 0);

        // New dividend
        vm.prank(dave);
        token.recordDividend{ value: 100 }();

        // alice: 25/100 * 100 = 25, bob: 50/100 * 100 = 50, charlie: 25
        assertEq(token.getWithdrawableDividend(alice), 250 + 25);
        assertEq(token.getWithdrawableDividend(bob), 0 + 50);
        assertEq(token.getWithdrawableDividend(charlie), 250 + 25);
    }

    function test_withdrawAfterHolderRelinquishesTokens() public {
        // Bob burns (sends ETH to dest) then withdraws dividend (also to dest)
        uint256 preBal = dest.balance;

        vm.prank(bob);
        token.burn(payable(dest)); // sends 50 ETH

        vm.prank(bob);
        token.withdrawDividend(payable(dest)); // sends 500 ETH

        assertEq(dest.balance - preBal, 50 + 500);

        // New dividend: bob no longer a holder
        vm.prank(dave);
        token.recordDividend{ value: 80 }();

        // alice: 25/50 * 80 = 40, bob: 0, charlie: 25/50 * 80 = 40
        assertEq(token.getWithdrawableDividend(alice), 250 + 40);
        assertEq(token.getWithdrawableDividend(bob), 0);
        assertEq(token.getWithdrawableDividend(charlie), 250 + 40);
    }
}

contract TokenEdgeCasesTest is BaseTest {
    function test_mintOneThenBurn() public {
        _mint(alice, 1);
        assertEq(token.totalSupply(), 1);
        vm.prank(alice);
        token.burn(payable(dest));
        assertEq(token.totalSupply(), 0);
        assertEq(token.getNumTokenHolders(), 0);
    }

    function test_transferFullBalanceThenMintAgain() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.transfer(bob, 100);
        assertEq(token.getNumTokenHolders(), 1);

        _mint(alice, 50);
        assertEq(token.getNumTokenHolders(), 2);
    }

    function test_multipleOperationsSequence() public {
        // Complex sequence: mint, transfer, approve, transferFrom, burn, dividend
        _mint(alice, 100);
        _mint(bob, 100);

        vm.prank(alice);
        token.transfer(charlie, 50);

        vm.prank(bob);
        token.approve(alice, 30);

        vm.prank(alice);
        token.transferFrom(bob, charlie, 30);

        // alice: 50, bob: 70, charlie: 80
        assertEq(token.balanceOf(alice), 50);
        assertEq(token.balanceOf(bob), 70);
        assertEq(token.balanceOf(charlie), 80);
        assertEq(token.totalSupply(), 200);

        vm.deal(dave, 2000);
        vm.prank(dave);
        token.recordDividend{ value: 2000 }();

        // alice: 50/200 * 2000 = 500, bob: 70/200 * 2000 = 700, charlie: 80/200 * 2000 = 800
        assertEq(token.getWithdrawableDividend(alice), 500);
        assertEq(token.getWithdrawableDividend(bob), 700);
        assertEq(token.getWithdrawableDividend(charlie), 800);
    }

    function test_largeMintValue() public {
        uint256 amount = 100 ether;
        vm.deal(alice, amount);
        _mint(alice, amount);
        assertEq(token.balanceOf(alice), amount);
        assertEq(address(token).balance, amount);
    }

    function test_getTokenHolderEmptyList() public view {
        assertEq(token.getTokenHolder(0), address(0));
        assertEq(token.getTokenHolder(1), address(0));
    }

    function test_transferToExistingHolder() public {
        _mint(alice, 100);
        _mint(bob, 50);
        vm.prank(alice);
        token.transfer(bob, 30);
        assertEq(token.balanceOf(bob), 80);
        assertEq(token.getNumTokenHolders(), 2); // No duplicate
    }

    function test_approveWithoutBalance() public {
        // Can approve even with zero balance
        vm.prank(charlie);
        token.approve(alice, 100);
        assertEq(token.allowance(charlie, alice), 100);
    }

    function test_transferFromToSelf() public {
        _mint(alice, 100);
        vm.prank(alice);
        token.approve(alice, 50);
        vm.prank(alice);
        token.transferFrom(alice, alice, 50);
        assertEq(token.balanceOf(alice), 100);
        assertEq(token.allowance(alice, alice), 0);
    }
}
