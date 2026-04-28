// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IEscrow {
  function fund(uint256, address, uint256, address) external payable;
  function releaseWithFees(
    uint256 id,
    address payee,
    address protocolFeeTo, uint16 protocolFeeBps
  ) external;
  function refund(uint256 id, address to) external;
}

/**
 * @title VehicleSaleCore
 * @notice Minimal P2P vehicle sale settlement rail.
 *
 * Core properties:
 * - Only current ERC-721 owner can create an offer.
 * - Buyer funds escrow.
 * - Seller finalizes by transferring the vehicle token to buyer and releasing escrow.
 * - If not finalized within 5 days of funding, buyer can refund.
 * - Dispute raised by either party within 5 days of funding results in refund.
 *   No arbitration on-chain. Neutral freeze resolves to buyer.
 * - Platform fee handling is not a protocol concern.
 *
 * Notes:
 * - Legal registry update is off-chain through platforms.
 * - This contract only settles funds and the ERC-721 vehicle token transfer.
 * - Protocol fee is immutable at 0.3% (30 bps).
 */
contract VehicleSaleCore is Ownable2Step, ReentrancyGuard {
  enum State { None, Offered, Funded, Disputed, Finalized, Cancelled }

  struct Sale {
    address vehicleContract;
    uint256 vehicleId;

    address seller;
    address buyer;

    address paymentToken; // address(0) => ETH
    uint256 price;

    uint64  createdAt;
    uint64  fundedAt;
    uint64  finalizedAt;

    // Optional off-chain agreement anchor (non-PII recommended)
    bytes32 termsCommitment;

    State   state;
  }

  IEscrow public immutable escrow;
  address public immutable protocolTreasury;
  uint16  public immutable protocolFeeBps; // 30 bps = 0.3%

  // Fixed 5-day windows. Not adjustable, fixed windows cannot be captured.
  uint64 public constant FINALIZE_EXPIRY = 5 days;
  uint64 public constant DISPUTE_WINDOW  = 5 days;

  mapping(uint256 => Sale) public sales;

  event OfferCreated(
    uint256 indexed saleId,
    address indexed seller,
    address vehicleContract,
    uint256 vehicleId,
    address paymentToken,
    uint256 price
  );
  event Funded(uint256 indexed saleId, address indexed buyer);
  event DisputeRaised(uint256 indexed saleId, address indexed by);
  event Finalized(uint256 indexed saleId, address indexed seller, address indexed buyer);
  event Cancelled(uint256 indexed saleId);
  event Refunded(uint256 indexed saleId, address indexed buyer);

  constructor(
    address escrow_,
    address protocolTreasury_,
    uint16  protocolFeeBps_
  ) Ownable(msg.sender) {
    require(escrow_ != address(0) && protocolTreasury_ != address(0), "bad-addr");
    require(protocolFeeBps_ < 10000, "bad-bps");
    escrow           = IEscrow(escrow_);
    protocolTreasury = protocolTreasury_;
    protocolFeeBps   = protocolFeeBps_;
  }

  receive() external payable {}

  function _isApproved(
    address vehicleContract,
    uint256 vehicleId,
    address owner
  ) internal view returns (bool) {
    IERC721 nft = IERC721(vehicleContract);
    return (nft.getApproved(vehicleId) == address(this)) ||
            nft.isApprovedForAll(owner, address(this));
  }

  /**
   * @notice Seller creates a sale offer for a vehicle they currently own.
   * @dev saleId chosen by caller for deterministic addressing.
   */
  function createOffer(
    uint256 saleId,
    address vehicleContract,
    uint256 vehicleId,
    address paymentToken,
    uint256 price,
    bytes32 termsCommitment
  ) external {
    require(sales[saleId].state == State.None, "exists");
    require(vehicleContract != address(0), "bad-vehicle");
    require(price > 0, "price=0");
    require(IERC721(vehicleContract).ownerOf(vehicleId) == msg.sender, "not-vehicle-owner");

    sales[saleId] = Sale({
      vehicleContract: vehicleContract,
      vehicleId:       vehicleId,
      seller:          msg.sender,
      buyer:           address(0),
      paymentToken:    paymentToken,
      price:           price,
      createdAt:       uint64(block.timestamp),
      fundedAt:        0,
      finalizedAt:     0,
      termsCommitment: termsCommitment,
      state:           State.Offered
    });

    emit OfferCreated(saleId, msg.sender, vehicleContract, vehicleId, paymentToken, price);
  }

  /**
   * @notice Seller can cancel before funding.
   */
  function cancelOffer(uint256 saleId) external {
    Sale storage S = sales[saleId];
    require(S.state == State.Offered, "bad-state");
    require(S.seller == msg.sender, "not-seller");
    S.state = State.Cancelled;
    emit Cancelled(saleId);
  }

  /**
   * @notice Buyer funds escrow.
   * @dev For ETH payments send msg.value = price.
   */
  function fund(uint256 saleId) external payable nonReentrant {
    Sale storage S = sales[saleId];
    require(S.state == State.Offered, "bad-state");
    require(IERC721(S.vehicleContract).ownerOf(S.vehicleId) == S.seller, "vehicle-moved");

    S.buyer    = msg.sender;
    S.fundedAt = uint64(block.timestamp);
    S.state    = State.Funded;

    if (S.paymentToken == address(0)) {
      require(msg.value == S.price, "bad-value");
      escrow.fund{value: S.price}(saleId, address(0), S.price, msg.sender);
    } else {
      require(msg.value == 0, "no-eth");
      escrow.fund(saleId, S.paymentToken, S.price, msg.sender);
    }

    emit Funded(saleId, msg.sender);
  }

  /**
   * @notice Either party can raise a dispute within DISPUTE_WINDOW after funding.
   * @dev Dispute leads to refund. No on-chain arbitration. Neutral freeze resolves to buyer.
   */
  function raiseDispute(uint256 saleId) external {
    Sale storage S = sales[saleId];
    require(S.state == State.Funded, "bad-state");
    require(msg.sender == S.seller || msg.sender == S.buyer, "not-party");
    require(block.timestamp <= uint256(S.fundedAt) + DISPUTE_WINDOW, "late");

    S.state = State.Disputed;
    emit DisputeRaised(saleId, msg.sender);
  }

  /**
   * @notice Refund buyer after dispute. Permissionless anyone can finalize the refund.
   */
  function refundOnDispute(uint256 saleId) external nonReentrant {
    Sale storage S = sales[saleId];
    require(S.state == State.Disputed, "bad-state");

    escrow.refund(saleId, S.buyer);

    S.state = State.Cancelled;
    emit Refunded(saleId, S.buyer);
    emit Cancelled(saleId);
  }

  /**
   * @notice Seller finalizes the sale:
   *         transfers the vehicle token to buyer, releases escrow to seller minus protocol fee.
   * @dev Seller must approve this contract to transfer the vehicle token before calling.
   */
  function finalize(uint256 saleId) external nonReentrant {
    Sale storage S = sales[saleId];
    require(S.state == State.Funded, "bad-state");
    require(S.seller == msg.sender, "not-seller");
    require(IERC721(S.vehicleContract).ownerOf(S.vehicleId) == S.seller, "vehicle-moved");
    require(_isApproved(S.vehicleContract, S.vehicleId, S.seller), "not-approved");

    // Transfer vehicle token first, then release funds.
    IERC721(S.vehicleContract).safeTransferFrom(S.seller, S.buyer, S.vehicleId);

    escrow.releaseWithFees(
      saleId,
      S.seller,
      protocolTreasury, protocolFeeBps
    );

    S.finalizedAt = uint64(block.timestamp);
    S.state       = State.Finalized;

    emit Finalized(saleId, S.seller, S.buyer);
  }

  /**
   * @notice Buyer protection: if seller never finalizes within FINALIZE_EXPIRY,
   *         anyone can trigger a refund to the buyer.
   */
  function refundIfExpired(uint256 saleId) external nonReentrant {
    Sale storage S = sales[saleId];
    require(S.state == State.Funded, "bad-state");
    require(block.timestamp > uint256(S.fundedAt) + FINALIZE_EXPIRY, "not-expired");

    escrow.refund(saleId, S.buyer);

    S.state = State.Cancelled;
    emit Refunded(saleId, S.buyer);
    emit Cancelled(saleId);
  }
}