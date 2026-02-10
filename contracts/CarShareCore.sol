// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IEscrow {
  function fund(uint256, address, uint256, address) external payable;
  function releaseWithFees(
    uint256 id,
    address payee,
    address platformFeeTo, uint16 platformFeeBps,
    address protocolFeeTo, uint16 protocolFeeBps,
    address caller,        uint16 callerTipBps
  ) external;
  function refund(uint256 id, address to) external;
}

/**
 * @title CarShareCore
 * @notice Minimal car-share / car-rental settlement rail.
 *         - Vehicle identity is an external ERC-721 (VehicleRegistry)
 *         - Rental agreement is a state machine keyed by rentalId
 *         - Escrow holds funds and releases on finalize
 *
 * Design goals:
 * - protocol neutrality: no KYC, no GPS, no reputation, no insurance
 * - minimal on-chain data: only hashes/commitments for pickup/return policies
 * - immutable protocol fee (default: 0.5%)
 */
contract CarShareCore is Ownable2Step {
  enum State { None, Offered, Booked, PickedUp, Returned, Disputed, Finalized, Cancelled }

  struct Rental {
    address vehicleContract;
    uint256 vehicleId;

    address lender;
    address renter;

    // schedule
    uint64  startTime;
    uint64  endTime;

    // timings recorded on-chain (optional signals)
    uint64  bookedAt;
    uint64  pickupAt;
    uint64  returnAt;

    // economics
    address paymentToken; // address(0) => ETH
    uint256 price;        // paid to lender (minus fees)
    uint256 deposit;      // refunded to renter on successful finalize

    // commitments (off-chain descriptors)
    bytes32 pickupCommitment;     // hash of pickup location + instructions bundle
    bytes32 returnPolicyRoot;     // merkle root of allowed return options, or any commitment hash

    // fee routing (optional integrating platform)
    address platformTreasury;
    uint16  platformFeeBps; // capped by maxPlatformFeeBps

    State   state;
  }

  IEscrow public immutable escrow;

  address public immutable protocolTreasury;
  uint16  public immutable protocolFeeBps; // e.g. 50 bps => 0.5%

  uint16 public maxPlatformFeeBps = 500;   // 5% cap, adjustable by owner
  uint64 public pickupGrace       = 30 minutes;
  uint64 public returnGrace       = 30 minutes;
  uint64 public disputeWindow     = 12 hours;

  mapping(uint256 => Rental) public rentals;

  event OfferCreated(uint256 indexed rentalId, address indexed lender, address vehicleContract, uint256 vehicleId);
  event Booked(uint256 indexed rentalId, address indexed renter);
  event PickupConfirmed(uint256 indexed rentalId);
  event ReturnClaimed(uint256 indexed rentalId);
  event DisputeRaised(uint256 indexed rentalId, address indexed by);
  event Finalized(uint256 indexed rentalId, address indexed winner);
  event Cancelled(uint256 indexed rentalId);

  constructor(
    address escrow_,
    address protocolTreasury_,
    uint16 protocolFeeBps_
  ) Ownable(msg.sender) {
    require(escrow_ != address(0) && protocolTreasury_ != address(0), "bad-addr");
    require(protocolFeeBps_ < 10000, "bad-bps");
    escrow = IEscrow(escrow_);
    protocolTreasury = protocolTreasury_;
    protocolFeeBps = protocolFeeBps_;
  }

  receive() external payable {}

  // Ledger id derivation: two ledgers per rental (price + deposit)
  function _priceLedger(uint256 rentalId) internal pure returns (uint256) { return rentalId << 1; }
  function _depositLedger(uint256 rentalId) internal pure returns (uint256) { return (rentalId << 1) | 1; }

  function setMaxPlatformFeeBps(uint16 v) external onlyOwner {
    require(v < 10000, "bad-bps");
    maxPlatformFeeBps = v;
  }
  function setGracePeriods(uint64 pickupGrace_, uint64 returnGrace_) external onlyOwner {
    pickupGrace = pickupGrace_;
    returnGrace = returnGrace_;
  }
  function setDisputeWindow(uint64 disputeWindow_) external onlyOwner {
    disputeWindow = disputeWindow_;
  }

  /**
   * @notice Lender creates a rental offer for a vehicle they currently own.
   * @dev rentalId is chosen by caller for deterministic addressing (e.g. sequential off-chain).
   */
  function createOffer(
    uint256 rentalId,
    address vehicleContract,
    uint256 vehicleId,
    uint64 startTime,
    uint64 endTime,
    address paymentToken,
    uint256 price,
    uint256 deposit,
    bytes32 pickupCommitment,
    bytes32 returnPolicyRoot,
    address platformTreasury_,
    uint16  platformFeeBps_
  ) external {
    require(rentals[rentalId].state == State.None, "exists");
    require(vehicleContract != address(0), "bad-vehicle");
    require(startTime < endTime, "bad-window");
    require(endTime > block.timestamp, "ended");
    require(price > 0, "price=0");
    require(platformFeeBps_ <= maxPlatformFeeBps, "platform-fee");

    // Ensure lender owns the vehicle at time of offer creation.
    require(IERC721(vehicleContract).ownerOf(vehicleId) == msg.sender, "not-vehicle-owner");

    rentals[rentalId] = Rental({
      vehicleContract: vehicleContract,
      vehicleId: vehicleId,
      lender: msg.sender,
      renter: address(0),
      startTime: startTime,
      endTime: endTime,
      bookedAt: 0,
      pickupAt: 0,
      returnAt: 0,
      paymentToken: paymentToken,
      price: price,
      deposit: deposit,
      pickupCommitment: pickupCommitment,
      returnPolicyRoot: returnPolicyRoot,
      platformTreasury: platformTreasury_,
      platformFeeBps: platformFeeBps_,
      state: State.Offered
    });

    emit OfferCreated(rentalId, msg.sender, vehicleContract, vehicleId);
  }

  function cancelOffer(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.state == State.Offered, "bad-state");
    require(R.lender == msg.sender, "not-lender");
    R.state = State.Cancelled;
    emit Cancelled(rentalId);
  }

  /**
   * @notice Renter books by funding escrow (price + deposit).
   * @dev For ETH payments, send msg.value = price + deposit.
   */
  function book(uint256 rentalId) external payable {
    Rental storage R = rentals[rentalId];
    require(R.state == State.Offered, "bad-state");
    require(block.timestamp <= R.startTime + pickupGrace, "too-late");
    // Re-check ownership at booking time.
    require(IERC721(R.vehicleContract).ownerOf(R.vehicleId) == R.lender, "vehicle-moved");

    R.renter = msg.sender;
    R.bookedAt = uint64(block.timestamp);
    R.state = State.Booked;

    uint256 total = R.price + R.deposit;

    if (R.paymentToken == address(0)) {
      require(msg.value == total, "bad-value");
      // split funding into two ledgers
      escrow.fund{value: R.price}(_priceLedger(rentalId), address(0), R.price, msg.sender);
      if (R.deposit > 0) {
        escrow.fund{value: R.deposit}(_depositLedger(rentalId), address(0), R.deposit, msg.sender);
      }
    } else {
      require(msg.value == 0, "no-eth");
      escrow.fund(_priceLedger(rentalId), R.paymentToken, R.price, msg.sender);
      if (R.deposit > 0) {
        escrow.fund(_depositLedger(rentalId), R.paymentToken, R.deposit, msg.sender);
      }
    }

    emit Booked(rentalId, msg.sender);
  }

  /**
   * @notice Renter confirms pickup (optional on-chain signal).
   */
  function confirmPickup(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.state == State.Booked, "bad-state");
    require(R.renter == msg.sender, "not-renter");
    require(block.timestamp + pickupGrace >= R.startTime, "too-early");

    R.pickupAt = uint64(block.timestamp);
    R.state = State.PickedUp;
    emit PickupConfirmed(rentalId);
  }

  /**
   * @notice Renter claims return (optional on-chain signal).
   * @dev Return location verification (merkle proof) is intentionally off-chain.
   */
  function claimReturn(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.state == State.PickedUp || R.state == State.Booked, "bad-state");
    require(R.renter == msg.sender, "not-renter");
    require(block.timestamp + returnGrace >= R.endTime, "too-early");

    R.returnAt = uint64(block.timestamp);
    R.state = State.Returned;
    emit ReturnClaimed(rentalId);
  }

  function raiseDispute(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.state == State.Returned, "bad-state");
    require(msg.sender == R.lender || msg.sender == R.renter, "not-party");
    require(block.timestamp <= uint256(R.returnAt) + disputeWindow, "late");

    R.state = State.Disputed;
    emit DisputeRaised(rentalId, msg.sender);
  }

  /**
   * @notice Finalize after return + dispute window, releasing price (minus fees) and refunding deposit.
   * @dev Anyone can call; caller tip bps is fixed at 0 for simplicity/minimalism.
   */
  function finalize(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.state == State.Returned, "bad-state");
    require(block.timestamp > uint256(R.returnAt) + disputeWindow, "not-final");

    // payout price with fee split
    escrow.releaseWithFees(
      _priceLedger(rentalId),
      R.lender,
      R.platformTreasury, R.platformFeeBps,
      protocolTreasury,  protocolFeeBps,
      msg.sender,        0
    );

    // refund deposit to renter
    if (R.deposit > 0) {
      escrow.refund(_depositLedger(rentalId), R.renter);
    }

    R.state = State.Finalized;
    emit Finalized(rentalId, R.lender);
  }

  /**
   * @notice If the lender cancels after booking (e.g., vehicle unavailable),
   *         lender can refund renter in full BEFORE pickup is confirmed.
   */
  function lenderCancelAndRefund(uint256 rentalId) external {
    Rental storage R = rentals[rentalId];
    require(R.lender == msg.sender, "not-lender");
    require(R.state == State.Booked, "bad-state");

    // refund both ledgers to renter
    escrow.refund(_priceLedger(rentalId), R.renter);
    if (R.deposit > 0) {
      escrow.refund(_depositLedger(rentalId), R.renter);
    }

    R.state = State.Cancelled;
    emit Cancelled(rentalId);
  }
}
