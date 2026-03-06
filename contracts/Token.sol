pragma solidity 0.7.0;

import "./IERC20.sol";
import "./IMintableToken.sol";
import "./IDividends.sol";
import "./SafeMath.sol";

/// @title Token - ERC-20 Mintable Token with Dividend Distribution
/// @notice Wrapped ETH token where callers mint by depositing ETH and burn to withdraw.
/// @dev Implements efficient holder tracking via swap-and-pop set for O(1) add/remove.
contract Token is IERC20, IMintableToken, IDividends {
  // ------------------------------------------ //
  // ----- BEGIN: DO NOT EDIT THIS SECTION ---- //
  // ------------------------------------------ //
  using SafeMath for uint256;
  uint256 public totalSupply;
  uint256 public decimals = 18;
  string public name = "Test token";
  string public symbol = "TEST";
  mapping (address => uint256) public balanceOf;
  // ------------------------------------------ //
  // ----- END: DO NOT EDIT THIS SECTION ------ //
  // ------------------------------------------ //

  // --- Events ---

  event Transfer(address indexed from, address indexed to, uint256 value);
  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Mint(address indexed account, uint256 amount);
  event Burn(address indexed account, address indexed dest, uint256 amount);
  event DividendRecorded(address indexed from, uint256 amount);
  event DividendWithdrawn(address indexed account, address indexed dest, uint256 amount);

  // --- State ---

  /// @dev owner => spender => allowance
  mapping(address => mapping(address => uint256)) private _allowances;

  /// @dev Accumulated withdrawable dividends per address
  mapping(address => uint256) private _withdrawableDividend;

  /// @dev Ordered array of holders with non-zero balance
  address[] private _holders;

  /// @dev 1-based index into _holders (0 means not a holder)
  mapping(address => uint256) private _holderIndex;

  // --- Modifiers ---

  /// @dev Requires msg.value > 0
  modifier requireETH() {
    require(msg.value > 0, "Token: must send ETH");
    _;
  }

  /// @dev Requires sender has at least `amount` tokens
  modifier hasSufficientBalance(address account, uint256 amount) {
    require(balanceOf[account] >= amount, "Token: insufficient balance");
    _;
  }

  /// @dev Requires spender has at least `amount` allowance from `owner`
  modifier hasSufficientAllowance(address owner, address spender, uint256 amount) {
    require(_allowances[owner][spender] >= amount, "Token: insufficient allowance");
    _;
  }

  // --- Internal: Holder Set Management ---

  /// @dev Adds account to holder set if it has a non-zero balance and is not already tracked
  function _addHolder(address account) internal {
    if (_holderIndex[account] == 0 && balanceOf[account] > 0) {
      _holders.push(account);
      _holderIndex[account] = _holders.length;
    }
  }

  /// @dev Removes account from holder set if its balance is zero (swap-and-pop O(1))
  function _removeHolder(address account) internal {
    uint256 idx = _holderIndex[account];
    if (idx == 0 || balanceOf[account] > 0) return;

    uint256 lastIdx = _holders.length;
    if (idx != lastIdx) {
      address lastHolder = _holders[lastIdx - 1];
      _holders[idx - 1] = lastHolder;
      _holderIndex[lastHolder] = idx;
    }
    _holders.pop();
    delete _holderIndex[account];
  }

  /// @dev Internal transfer logic with holder set updates (CEI pattern)
  function _transfer(address from, address to, uint256 value) internal {
    // Effects
    balanceOf[from] = balanceOf[from].sub(value);
    balanceOf[to] = balanceOf[to].add(value);

    // Holder tracking (only add if non-zero transfer)
    if (value > 0) {
      _addHolder(to);
    }
    _removeHolder(from);

    emit Transfer(from, to, value);
  }

  // --- IERC20 ---

  /// @notice Returns the remaining allowance that `spender` can spend on behalf of `owner`
  function allowance(address owner, address spender) external view override returns (uint256) {
    return _allowances[owner][spender];
  }

  /// @notice Transfers `value` tokens from caller to `to`
  /// @dev Reverts if caller has insufficient balance. Transfer of 0 does not add `to` to holder list.
  function transfer(address to, uint256 value)
    external
    override
    hasSufficientBalance(msg.sender, value)
    returns (bool)
  {
    _transfer(msg.sender, to, value);
    return true;
  }

  /// @notice Sets `spender` allowance to `value` (overwrites previous)
  function approve(address spender, uint256 value) external override returns (bool) {
    _allowances[msg.sender][spender] = value;
    emit Approval(msg.sender, spender, value);
    return true;
  }

  /// @notice Transfers `value` tokens from `from` to `to` using caller's allowance
  /// @dev Reverts if `from` has insufficient balance or caller has insufficient allowance.
  function transferFrom(address from, address to, uint256 value)
    external
    override
    hasSufficientBalance(from, value)
    hasSufficientAllowance(from, msg.sender, value)
    returns (bool)
  {
    // Effects: decrement allowance first
    _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);
    _transfer(from, to, value);
    return true;
  }

  // --- IMintableToken ---

  /// @notice Deposit ETH and mint equal amount of tokens to caller
  /// @dev Reverts if no ETH is sent
  function mint() external payable override requireETH {
    // Effects
    balanceOf[msg.sender] = balanceOf[msg.sender].add(msg.value);
    totalSupply = totalSupply.add(msg.value);
    _addHolder(msg.sender);

    emit Mint(msg.sender, msg.value);
  }

  /// @notice Burns all of caller's tokens and sends equivalent ETH to `dest`
  /// @dev Follows CEI pattern: state changes before external call
  function burn(address payable dest) external override {
    uint256 amount = balanceOf[msg.sender];

    // Effects
    balanceOf[msg.sender] = 0;
    totalSupply = totalSupply.sub(amount);
    _removeHolder(msg.sender);

    emit Burn(msg.sender, dest, amount);

    // Interaction
    dest.transfer(amount);
  }

  // --- IDividends ---

  /// @notice Returns number of token holders with non-zero balance
  function getNumTokenHolders() external view override returns (uint256) {
    return _holders.length;
  }

  /// @notice Returns holder address at 1-based index, or address(0) if out of bounds
  function getTokenHolder(uint256 index) external view override returns (address) {
    if (index == 0 || index > _holders.length) {
      return address(0);
    }
    return _holders[index - 1];
  }

  /// @notice Records a dividend proportional to each holder's share of total supply
  /// @dev Loops through all current holders. Reverts if no ETH is sent.
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

  /// @notice Returns the withdrawable dividend for `payee`
  function getWithdrawableDividend(address payee) external view override returns (uint256) {
    return _withdrawableDividend[payee];
  }

  /// @notice Withdraws caller's accumulated dividend to `dest`
  /// @dev Follows CEI pattern: zeroes balance before sending ETH
  function withdrawDividend(address payable dest) external override {
    uint256 amount = _withdrawableDividend[msg.sender];

    // Effects
    _withdrawableDividend[msg.sender] = 0;

    emit DividendWithdrawn(msg.sender, dest, amount);

    // Interaction
    dest.transfer(amount);
  }
}
