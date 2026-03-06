// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../helpers/BaseTest.sol";

contract TokenFuzzTest is BaseTest {
    function test_fuzz_mint(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(alice, uint256(amount));
        _mint(alice, uint256(amount));

        assertEq(token.balanceOf(alice), uint256(amount));
        assertEq(token.totalSupply(), uint256(amount));
        assertEq(address(token).balance, uint256(amount));
        assertEq(token.getNumTokenHolders(), 1);
    }

    function test_fuzz_mintAndBurn(uint96 amount) public {
        vm.assume(amount > 0);
        vm.deal(alice, uint256(amount));
        _mint(alice, uint256(amount));

        vm.prank(alice);
        token.burn(payable(dest));

        assertEq(token.balanceOf(alice), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(address(token).balance, 0);
        assertEq(dest.balance, uint256(amount));
        assertEq(token.getNumTokenHolders(), 0);
    }

    function test_fuzz_transfer(uint96 mintAmount, uint96 transferAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount <= mintAmount);

        vm.deal(alice, uint256(mintAmount));
        _mint(alice, uint256(mintAmount));

        vm.prank(alice);
        token.transfer(bob, uint256(transferAmount));

        assertEq(token.balanceOf(alice), uint256(mintAmount) - uint256(transferAmount));
        assertEq(token.balanceOf(bob), uint256(transferAmount));
        assertEq(token.totalSupply(), uint256(mintAmount));
    }

    function test_fuzz_approve(uint96 amount) public {
        vm.prank(alice);
        token.approve(bob, uint256(amount));
        assertEq(token.allowance(alice, bob), uint256(amount));
    }

    function test_fuzz_transferFrom(uint96 mintAmount, uint96 approveAmount, uint96 transferAmount) public {
        vm.assume(mintAmount > 0);
        vm.assume(approveAmount > 0);
        vm.assume(transferAmount > 0);
        vm.assume(transferAmount <= approveAmount);
        vm.assume(transferAmount <= mintAmount);

        vm.deal(alice, uint256(mintAmount));
        _mint(alice, uint256(mintAmount));

        vm.prank(alice);
        token.approve(bob, uint256(approveAmount));

        vm.prank(bob);
        token.transferFrom(alice, charlie, uint256(transferAmount));

        assertEq(token.balanceOf(alice), uint256(mintAmount) - uint256(transferAmount));
        assertEq(token.balanceOf(charlie), uint256(transferAmount));
        assertEq(token.allowance(alice, bob), uint256(approveAmount) - uint256(transferAmount));
    }

    function test_fuzz_dividendProportional(uint96 aliceAmount, uint96 bobAmount, uint96 dividend) public {
        vm.assume(aliceAmount > 0);
        vm.assume(bobAmount > 0);
        vm.assume(dividend > 0);
        uint256 total = uint256(aliceAmount) + uint256(bobAmount);
        vm.assume(total < type(uint96).max); // avoid overflow in mul

        vm.deal(alice, uint256(aliceAmount));
        vm.deal(bob, uint256(bobAmount));
        _mint(alice, uint256(aliceAmount));
        _mint(bob, uint256(bobAmount));

        vm.deal(dave, uint256(dividend));
        vm.prank(dave);
        token.recordDividend{ value: uint256(dividend) }();

        uint256 aliceShare = uint256(dividend) * uint256(aliceAmount) / total;
        uint256 bobShare = uint256(dividend) * uint256(bobAmount) / total;

        assertEq(token.getWithdrawableDividend(alice), aliceShare);
        assertEq(token.getWithdrawableDividend(bob), bobShare);
    }

    function test_fuzz_withdrawDividend(uint96 amount, uint96 dividend) public {
        vm.assume(amount > 0);
        vm.assume(dividend > 0);

        vm.deal(alice, uint256(amount));
        _mint(alice, uint256(amount));

        vm.deal(dave, uint256(dividend));
        vm.prank(dave);
        token.recordDividend{ value: uint256(dividend) }();

        uint256 preBal = dest.balance;
        vm.prank(alice);
        token.withdrawDividend(payable(dest));

        assertEq(dest.balance - preBal, uint256(dividend));
        assertEq(token.getWithdrawableDividend(alice), 0);
    }
}
