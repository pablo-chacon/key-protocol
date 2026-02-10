// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

/**
 * @title VehicleRegistry
 * @notice Minimal ERC-721 identity registry for real-world vehicles.
 *         Stores only integrity anchors (hashes) and an optional terms/metadata URI.
 *         All PII and operational details MUST remain off-chain.
 *
 * CHANGE:
 * - Removed registryHash entirely (no license plate, not even optional).
 */
contract VehicleRegistry is ERC721, Ownable2Step {
  struct Vehicle {
    bytes32 vinHash;     // keccak256(vin || salt)
    bytes32 specHash;    // keccak256(canonical_json_specs)
    uint64  createdAt;
    string  termsURI;    // IPFS/HTTPS to terms + metadata bundle (non-PII recommended)
  }

  mapping(uint256 => Vehicle) public vehicles;

  event VehicleMinted(
    uint256 indexed vehicleId,
    address indexed owner,
    bytes32 vinHash,
    bytes32 specHash,
    string termsURI
  );

  constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) Ownable(msg.sender) {}

  /**
   * @notice Mint a new vehicle identity.
   * @dev TokenId is chosen by caller for deterministic mapping (for example hash of vinHash).
   */
  function mint(
    uint256 vehicleId,
    address to,
    bytes32 vinHash,
    bytes32 specHash,
    string calldata termsURI
  ) external {
    require(_ownerOf(vehicleId) == address(0), "exists");
    require(to != address(0), "bad-to");
    require(vinHash != bytes32(0), "vinHash=0");
    require(specHash != bytes32(0), "specHash=0");

    _safeMint(to, vehicleId);

    vehicles[vehicleId] = Vehicle({
      vinHash: vinHash,
      specHash: specHash,
      createdAt: uint64(block.timestamp),
      termsURI: termsURI
    });

    emit VehicleMinted(vehicleId, to, vinHash, specHash, termsURI);
  }

  /**
   * @notice Optional: owner can update termsURI.
   * @dev Does not alter identity hashes.
   */
  function setTermsURI(uint256 vehicleId, string calldata newTermsURI) external {
    require(ownerOf(vehicleId) == msg.sender, "not-owner");
    vehicles[vehicleId].termsURI = newTermsURI;
  }
}
