// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @dev Combined interface mirroring Token.sol's public API for cross-version testing
interface IToken {
    // ERC-20
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    // Mintable
    function mint() external payable;
    function burn(address payable dest) external;

    // Dividends
    function getNumTokenHolders() external view returns (uint256);
    function getTokenHolder(uint256 index) external view returns (address);
    function recordDividend() external payable;
    function getWithdrawableDividend(address payee) external view returns (uint256);
    function withdrawDividend(address payable dest) external;
}
