// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

/// @notice Smoke test to verify Forge toolchain is configured correctly
contract SetupTest is Test {
    function test_forgeIsConfigured() public pure {
        assertTrue(true, "Forge is working");
    }
}
