// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../interfaces/IToken.sol";

/// @dev Base test contract that deploys Token via bytecode (cross-version)
abstract contract BaseTest is Test {
    IToken internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal charlie = makeAddr("charlie");
    address internal dave = makeAddr("dave");
    address internal dest = makeAddr("dest");

    function setUp() public virtual {
        // Deploy the 0.7.0 Token contract using its compiled artifact
        address deployed = deployCode("Token.sol:Token");
        token = IToken(deployed);

        // Fund test accounts
        vm.deal(alice, 1000 ether);
        vm.deal(bob, 1000 ether);
        vm.deal(charlie, 1000 ether);
        vm.deal(dave, 1000 ether);
    }

    /// @dev Helper: mint tokens for a user
    function _mint(address user, uint256 amount) internal {
        vm.prank(user);
        token.mint{ value: amount }();
    }

    /// @dev Helper: check holder list contains exactly these addresses (order-independent)
    function _assertHolders(address[] memory expected) internal view {
        uint256 n = token.getNumTokenHolders();
        assertEq(n, expected.length, "holder count mismatch");

        // Collect actual holders
        address[] memory actual = new address[](n);
        for (uint256 i = 0; i < n; i++) {
            actual[i] = token.getTokenHolder(i + 1);
        }

        // Check each expected is in actual
        for (uint256 i = 0; i < expected.length; i++) {
            bool found = false;
            for (uint256 j = 0; j < actual.length; j++) {
                if (actual[j] == expected[i]) {
                    found = true;
                    break;
                }
            }
            assertTrue(found, "expected holder not found");
        }
    }
}
