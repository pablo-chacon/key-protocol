
---

# KEY Protocol

**Decentralized Vehicle Ownership, Rental, and Sale Settlement**

---

## Legal Disclaimer

This repository contains general-purpose, open-source smart contracts.
The authors and contributors:

* do not operate any vehicle marketplace, rental service, dealership, or registry
* do not verify vehicle ownership, identity, or legal compliance
* do not provide legal, financial, or tax advice
* are not responsible for deployments, integrations, or real-world usage

All deployments of KEY Protocol are performed **at the risk of the deployer and the integrating platform**.

No warranty of any kind is provided.
The software is offered strictly **as-is**, without guarantees of fitness for any purpose.
The authors are not liable for any damages, losses, claims, or issues arising from the use, misuse, or failure of this software or any derivative work.

By using, deploying, integrating, or interacting with this software in any form, you agree that all responsibility for legal compliance, operation, and outcomes lies solely with you.

---

## Protocol Finality & Immutability

**KEY Protocol is finished infrastructure.**

The core smart contracts are intentionally minimal, deterministic, and **will not be modified, upgraded, or extended**. There is no upgrade path, governance mechanism, or maintainer intervention.

KEY is provided as neutral, general-purpose settlement infrastructure. Its behavior is fully defined by the deployed code and does not depend on any individual, organization, or ongoing development.

All future innovation is expected to happen **off-chain or on top of the protocol**, without requiring changes to the protocol itself.

---

## **KEY Protocol: Neutral Vehicle Ownership & Usage Settlement (Ethereum-Mainnet)**

**KEY Protocol** is a minimal, self-contained, production-ready settlement layer for:

* vehicle ownership anchoring
* peer-to-peer vehicle rental and sharing
* peer-to-peer vehicle sale and purchase

Ownership intent, rental agreements, and sale settlement are expressed on-chain.
Legal ownership transfer, identity verification, and registry interaction are performed **off-chain by platforms**.

**This repository contains only the immutable smart contracts and deployment script.**

---

## **Ethereum Mainnet Deployment**

Official KEY Protocol contract addresses:

* **VehicleRegistry:** *TBD*
* **CarShareCore:** *TBD*
* **VehicleSaleCore:** *TBD*
* **Escrow:** *TBD*
* **protocolTreasury:** *TBD*

---

## **Start building**

KEY Protocol is designed to be integrated by platforms that handle:

* legal vehicle registries
* KYC / AML
* identity verification
* insurance and compliance

[Templates and reference integrations here.](https://github.com/pablo-chacon/key-templates/tree/main)

---

## **Repo Structure**

```
.
├── contracts
│   ├── Escrow.sol
│   ├── VehicleRegistry.sol
│   ├── CarShareCore.sol
│   └── VehicleSaleCore.sol
├── foundry.toml
├── README.md
└── script
    └── DeployProtocol.s.sol
```

---

## **Centralized Vehicle Platforms VS KEY Protocol**

| **System Function**  | **Centralized Platforms** | **KEY Protocol**         |
| -------------------- | ------------------------- | ------------------------ |
| Vehicle identity     | Platform database         | ERC-721 identity anchor  |
| Ownership change     | Manual + opaque           | On-chain intent + escrow |
| Rental settlement    | Platform custody          | Trustless escrow         |
| Sale settlement      | Dealer-controlled         | Atomic NFT + escrow      |
| Fees                 | Mutable, opaque           | Immutable protocol fee   |
| Registry integration | Closed                    | Platform-defined         |
| User data            | Collected and monetized   | No data extraction       |
| Upgrades             | Continuous                | None                     |

---

## **NFT as a representation of a physical vehicle**

KEY uses NFTs as **non-speculative infrastructure**.

An NFT is a globally unique, transferable authority container.
It does not represent value, ownership legitimacy, or legal title by itself.

In KEY, the vehicle NFT anchors:

* **vehicleId**
* **immutable VIN commitment (vinHash)**
* **immutable vehicle spec commitment (specHash)**
* **escrow authority**
* **settlement rights**

The protocol **does not store**:

* license plate numbers
* owner identity
* registry identifiers
* location data

Possession of the NFT represents the right to initiate **settlement actions**.
Legal ownership change requires off-chain registry interaction and is **one-way** from chain intent to registry update.

---

## **What KEY Protocol Provides**

### **1. VehicleRegistry: vehicle identity anchor**

* ERC-721 per vehicle
* Immutable hash commitments only
* No mutable metadata affecting identity
* Permissionless minting by design

The registry is an integrity anchor, not a legal registry.

---

### **2. CarShareCore: rental & sharing settlement**

* Owner-only rental offers
* Escrowed rental price + deposit
* Deterministic lifecycle:

  * Offered → Booked → PickedUp → Returned → Finalized
* Automatic settlement after dispute window
* Immutable protocol fee (default 0.5%)
* Optional platform fee

No enforcement, no GPS, no arbitration logic.

---

### **3. VehicleSaleCore: sale & purchase settlement**

* Owner-only sale offers
* Buyer-funded escrow
* Atomic ERC-721 transfer + payment release
* Time-based buyer protection
* Neutral dispute freeze with refund
* Immutable protocol fee (default 0.5%)

Legal ownership transfer happens off-chain through platforms.

---

### **4. Escrow: neutral settlement rail**

* Holds ETH or ERC-20 funds
* Releases funds based on core contract state
* Applies protocol and platform fees at payout
* Shared by all KEY cores

---

## **Finalization and Disputes**

### **Rental Finalization**

* After return + dispute window:

  * Rental price released to lender (minus fees)
  * Deposit refunded to renter
* Anyone may call `finalize`
* No subjective judgment on-chain

### **Sale Finalization**

* Seller transfers vehicle NFT to buyer
* Escrow releases payment atomically
* If seller does not finalize:

  * Buyer may refund after expiry
* Disputes result in refund, not arbitration

---

## **Quick Start (Local)**

### **Prerequisites**

[foundry](https://getfoundry.sh/)

### **1. Install**

```bash
forge install
forge test -vv
```

### **2. Configure deployment**

```bash
cp .env.deploy.example .env.deploy
```

Set:

* `DEPLOYER_KEY`
* `PROTOCOL_TREASURY`
* `PROTOCOL_FEE_BPS`

### **3. Deploy**

```bash
anvil
forge script script/DeployProtocol.s.sol:DeployProtocol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --env-file .env.deploy
```

---

## **Security Model**

* No upgradeability
* No governance hooks
* Protocol fee is immutable
* Platform fee is bounded
* Ownership of cores should be:

  * multisig
  * Safe
  * or fully renounced

---

## **Philosophy**

KEY Protocol is:

* Minimal
* Neutral
* Deterministic
* Permissionless
* Designed to outlive its author

KEY does not replace registries, platforms, or law.
It provides a **cryptographic settlement substrate** that those systems may choose to use.

---

## **License**

MIT License

Copyright (c) 2025 Pablo-Chacon

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND.

---

## **Contact**

**[Contact Email](pablo-chacon-ai@proton.me)**

---

