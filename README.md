# KEY Protocol

**Decentralized Vehicle Ownership and Sale Settlement**

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts.
The authors and contributors:

* do not operate any vehicle marketplace, rental service, dealership, or registry
* do not verify vehicle ownership, identity, or legal compliance
* do not provide legal, financial, or tax advice
* are not responsible for deployments, integrations, or real-world usage

All deployments of KEY Protocol are performed **at the risk of the deployer and the integrating platform**.

No warranty of any kind is provided. The software is offered strictly **as-is**, without guarantees of fitness for any purpose. The authors are not liable for any damages, losses, claims, or issues arising from the use, misuse, or failure of this software or any derivative work.

By using, deploying, integrating, or interacting with this software in any form, you agree that all responsibility for legal compliance, operation, and outcomes lies solely with you.

---

## Protocol Finality and Immutability

**KEY Protocol is finished infrastructure.**

The core smart contracts are intentionally minimal, deterministic, and will not be modified, upgraded, or extended. There is no upgrade path, governance mechanism, or maintainer intervention.

KEY is provided as neutral, general-purpose settlement infrastructure. Its behavior is fully defined by the deployed code and does not depend on any individual, organization, or ongoing development.

All future innovation is expected to happen off-chain or on top of the protocol, without requiring changes to the protocol itself.

---

## KEY Protocol: Neutral Vehicle Ownership and Sale Settlement

KEY Protocol is a minimal, self-contained, production-ready settlement layer for:

* vehicle ownership anchoring
* peer-to-peer vehicle sale and purchase

Ownership intent and sale settlement are expressed on-chain. Legal ownership transfer, identity verification, and registry interaction are performed off-chain by platforms.

**This repository contains only the immutable smart contracts and deployment script.**

---

## Ethereum Mainnet Deployment

Official KEY Protocol contract addresses:

* **VehicleRegistry:** *TBD*
* **VehicleSaleCore:** *TBD*
* **Escrow:** *TBD*
* **protocolTreasury:** *TBD*

---

## Start Building

KEY Protocol is designed to be integrated by platforms that handle:

* legal vehicle registries
* KYC / AML
* identity verification
* insurance and compliance

Platform fee handling is not a protocol concern. Platforms handle their own fee logic upstream — the protocol settles only the protocol fee of 0.3% at finalization.

[Templates and reference integrations here.](https://github.com/pablo-chacon/key-templates/tree/main)

---

## Repo Structure

```
.
├── contracts
│   ├── Escrow.sol
│   ├── VehicleRegistry.sol
│   └── VehicleSaleCore.sol
├── foundry.toml
├── README.md
└── script
    └── DeployProtocol.s.sol
```

---

## Centralized Vehicle Platforms vs KEY Protocol

| System Function      | Centralized Platforms     | KEY Protocol             |
| -------------------- | ------------------------- | ------------------------ |
| Vehicle identity     | Platform database         | ERC-721 identity anchor  |
| Ownership change     | Manual and opaque         | On-chain intent + escrow |
| Sale settlement      | Dealer-controlled         | Atomic NFT + escrow      |
| Fees                 | Mutable, opaque           | Immutable protocol fee   |
| Registry integration | Closed                    | Platform-defined         |
| User data            | Collected and monetized   | No data extraction       |
| Upgrades             | Continuous                | None                     |

---

## NFT as a Representation of a Physical Vehicle

KEY uses NFTs as non-speculative infrastructure.

An NFT is a globally unique, transferable authority container. It does not represent value, ownership legitimacy, or legal title by itself.

In KEY, the vehicle NFT anchors:

* vehicleId
* immutable VIN commitment (vinHash)
* immutable vehicle spec commitment (specHash)
* escrow authority
* settlement rights

The protocol does not store:

* license plate numbers
* owner identity
* registry identifiers
* location data

Possession of the NFT represents the right to initiate settlement actions. Legal ownership change requires off-chain registry interaction and is one-way from chain intent to registry update.

---

## What KEY Protocol Provides

### 1. VehicleRegistry: vehicle identity anchor

* ERC-721 per vehicle
* Immutable hash commitments only
* No mutable metadata affecting identity
* Permissionless minting by design

The registry is an integrity anchor, not a legal registry.

---

### 2. VehicleSaleCore: sale and purchase settlement

* Owner-only sale offers
* Buyer-funded escrow
* Atomic ERC-721 transfer and payment release
* Fixed 5-day finalization window — if seller does not finalize, buyer may refund
* Fixed 5-day dispute window — either party may raise a dispute after funding
* Dispute results in refund to buyer. No arbitration on-chain.
* Immutable protocol fee of 0.3%
* Platform fee handling is not a protocol concern

Both time windows are protocol constants. They are not adjustable by any party.

---

### 3. Escrow: neutral settlement rail

* Holds ETH or ERC-20 funds
* Releases funds based on core contract state
* Applies protocol fee only at payout — no platform fee at the protocol layer
* Shared by VehicleRegistry and VehicleSaleCore

---

## Finalization and Disputes

### Sale Finalization

* Seller transfers vehicle NFT to buyer
* Escrow releases payment atomically minus 0.3% protocol fee
* If seller does not finalize within 5 days of funding: buyer or anyone may trigger refund
* If either party raises a dispute within 5 days of funding: sale freezes, refund to buyer
* No arbitration. No subjective decision on-chain. Neutral freeze resolves to buyer.

---

## Quick Start (Local)

### Prerequisites

[foundry](https://getfoundry.sh/)

### 1. Install

```bash
forge install
forge test -vv
```

### 2. Configure deployment

```bash
cp .env.deploy.example .env.deploy
```

Set:

* `DEPLOYER_KEY`
* `PROTOCOL_TREASURY`
* `PROTOCOL_FEE_BPS` — set to 30 (0.3%)

### 3. Deploy

```bash
anvil
forge script script/DeployProtocol.s.sol:DeployProtocol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --env-file .env.deploy
```

---

## Security Model

* No upgradeability
* No governance hooks
* Protocol fee is immutable
* No platform fee at the protocol layer
* Time windows are protocol constants — not adjustable by any party
* Ownership of cores should be multisig, Safe, or fully renounced

---

## Philosophy

KEY Protocol is:

* Minimal
* Neutral
* Deterministic
* Permissionless
* Designed to outlive its author

KEY does not replace registries, platforms, or law. It provides a cryptographic settlement substrate that those systems may choose to use.

---

## License

MIT License

Copyright (c) 2025 Pablo-Chacon

---

## Contact

pablo-chacon-ai@proton.me