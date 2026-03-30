---

# KEY Protocol Whitepaper

## A Neutral, Immutable Settlement Layer for Vehicle Ownership and Sale

---

## Abstract

KEY Protocol is a minimal blockchain protocol that defines **on-chain settlement of vehicle ownership intent and sale transactions**, while intentionally leaving **all legal enforcement, identity verification, and registry interaction off-chain**.

KEY does not operate a vehicle marketplace, rental service, dealership, or registry.
It provides **neutral, deterministic settlement primitives** that external platforms may use to coordinate real-world vehicle ownership and usage.

The protocol is designed to be **finished infrastructure**: immutable, non-governed, and capable of operating indefinitely without updates, maintainers, or institutional control.

---

## Design Principles

KEY Protocol is designed around the following principles:

### 1. Finality

The protocol is **complete and immutable**.
There are no upgrade paths, governance hooks, or future versions.

All behavior is defined entirely by the deployed code.

---

### 2. Neutrality

KEY does not encode:

* identity systems
* compliance rules
* jurisdictional logic
* enforcement mechanisms
* insurance models
* trust assumptions

All such concerns are **explicitly externalized to platforms**.

---

### 3. One-Way Legal Integration

KEY expresses **intent and settlement on-chain**.

Legal ownership transfer and registry updates occur **off-chain**, initiated by platforms using the on-chain intent as input.

No on-chain state can force a legal registry update.
No legal registry can mutate on-chain state directly.

This asymmetry is intentional.

---

### 4. Privacy by Construction

KEY stores **no personally identifiable information**.

On-chain data is limited to:

* cryptographic commitments (hashes)
* timestamps
* addresses
* amounts

All sensitive data remains off-chain.

---

### 5. Minimal Surface Area

KEY includes only what is strictly necessary to:

* anchor vehicle identity
* settle sale transactions
* transfer value deterministically

Anything else is excluded by design.

---

## What KEY Is Not

KEY Protocol explicitly does **not** provide:

* a vehicle registry
* legal title enforcement
* KYC or AML
* driver licensing
* insurance verification
* reputation systems
* dispute arbitration
* location tracking
* pricing algorithms
* matching or discovery

Any system requiring these must implement them **outside the protocol**.

---

## Core Architecture

KEY Protocol consists of three immutable contracts:

```
VehicleRegistry
      |
      |-- VehicleSaleCore
      |
    Escrow
```

Each contract has a single, narrow responsibility.

---

## Vehicle Identity as an NFT

### VehicleRegistry

Vehicles are represented as **ERC-721 tokens**.

Each token anchors:

* a unique `vehicleId`
* an immutable `vinHash`
* an immutable `specHash`

These hashes commit to constant vehicle properties without revealing plaintext data.

The registry:

* does not store license plates
* does not store owner identity
* does not store registry identifiers
* does not enforce uniqueness beyond token ID

Permissionless minting is allowed by design.

The registry is an **integrity anchor**, not a legal authority.

---

## Sale and Purchase Settlement

### VehicleSaleCore

VehicleSaleCore defines a **peer-to-peer sale settlement flow**:

1. Seller creates a sale offer (must own the vehicle NFT)
2. Buyer funds escrow
3. Seller transfers NFT to buyer
4. Escrow releases funds atomically

Buyer protection is provided via:

* time-based refund if seller does not finalize
* neutral dispute freeze resulting in refund

The protocol does not determine legal ownership.
It settles **payment and token transfer only**.

---

## Escrow and Value Transfer

### Escrow

Escrow is a shared, minimal settlement primitive:

* Holds ETH or ERC-20 tokens
* Releases funds based on core contract instructions
* Applies protocol and platform fees at payout
* Supports refunds deterministically

Escrow is trusted **only** by authorized core contracts.

---

## Fee Model

KEY Protocol enforces:

* an **immutable protocol fee** (e.g. 0.5%)
* an optional, bounded platform fee

Fees are:

* deducted at settlement
* visible on-chain
* non-modifiable post-deployment

The protocol fee exists to support audits, tooling, and ecosystem longevity without extracting control.

---

## Disputes and Finalization

KEY intentionally avoids arbitration.

Disputes are handled as follows:

* Sale disputes result in refund
* No subjective decision is made on-chain
* No oracle or judge is involved

Platforms may implement arbitration off-chain if desired.

---

## Security Model

KEY Protocol security relies on:

* minimal contract surface area
* no external oracles
* no upgradeability
* no dynamic configuration
* deterministic state transitions

Ownership of contracts should be:

* a multisig
* a Safe
* or fully renounced

---

## Longevity and Governance

KEY Protocol has **no governance**.

There are:

* no voting mechanisms
* no emergency switches
* no admin intervention paths

Once deployed, the protocol is intended to operate **without its author**.

---

## Ecosystem Integration

KEY is designed to be used by:

* vehicle marketplaces
* dealerships
* fleet operators
* DAO-based ownership systems
* jurisdiction-specific registry integrators

All integration logic lives **outside the protocol**.

---

## Conclusion

KEY Protocol is a **neutral settlement substrate** for vehicle ownership and sale.

It does not attempt to replace law, registries, or platforms.
It provides a cryptographic layer that those systems may optionally adopt.

Its strength lies in what it refuses to do.

KEY is finished infrastructure.

---

## License

MIT License

Copyright (c) 2025 Pablo-Chacon

---