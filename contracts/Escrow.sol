// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title Escrow
 * @notice Generic single-ledger escrow used by protocol cores.
 *         Stores funds per id, then releases with fee splits or refunds.
 *         Platform fee handling is not a protocol concern — handled upstream by platforms.
 */
contract Escrow is Ownable2Step {
  using SafeERC20 for IERC20;

  mapping(address => bool) public isCore;

  struct Ledger {
    address token;   // address(0) => ETH
    uint256 amount;
    address payer;
    bool    paid;
    bool    released;
  }

  mapping(uint256 => Ledger) public ledgers;

  modifier onlyCore() {
    require(isCore[msg.sender], "not-core");
    _;
  }

  constructor() Ownable(msg.sender) {}

  function setCore(address core, bool allowed) external onlyOwner {
    require(core != address(0), "bad-core");
    isCore[core] = allowed;
  }

  function fund(
    uint256 id,
    address token,
    uint256 amount,
    address payer
  ) external payable onlyCore {
    Ledger storage L = ledgers[id];
    require(!L.paid, "already-funded");
    require(amount > 0, "amount=0");

    L.token  = token;
    L.amount = amount;
    L.payer  = payer;
    L.paid   = true;

    if (token == address(0)) {
      require(msg.value == amount, "bad-value");
    } else {
      require(msg.value == 0, "no-eth");
      IERC20(token).safeTransferFrom(payer, address(this), amount);
    }
  }

  function releaseWithFees(
    uint256 id,
    address payee,
    address protocolFeeTo, uint16 protocolFeeBps
  ) external onlyCore {
    Ledger storage L = ledgers[id];
    require(L.paid && !L.released, "bad-ledger");
    L.released = true;

    require(protocolFeeBps < 10000, "bps");

    uint256 r = (L.amount * protocolFeeBps) / 10000;
    uint256 v = L.amount - r;

    if (L.token == address(0)) {
      if (r > 0) Address.sendValue(payable(protocolFeeTo), r);
      Address.sendValue(payable(payee), v);
    } else {
      IERC20 tok = IERC20(L.token);
      if (r > 0) tok.safeTransfer(protocolFeeTo, r);
      tok.safeTransfer(payee, v);
    }
  }

  function refund(uint256 id, address to) external onlyCore {
    Ledger storage L = ledgers[id];
    require(L.paid && !L.released, "bad-ledger");
    L.released = true;

    if (L.token == address(0)) {
      Address.sendValue(payable(to), L.amount);
    } else {
      IERC20(L.token).safeTransfer(to, L.amount);
    }
  }
}