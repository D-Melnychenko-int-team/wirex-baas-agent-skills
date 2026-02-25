---
name: wirex-baas-cards
description: "Wirex BaaS card management — issue Visa cards, retrieve card details, manage card lifecycle. Covers virtual, plastic, and metal card issuance and fees, card activation, block/unblock/close, card name change, sensitive card details (PAN/CVV/PIN via PCI endpoints with signature or OTP), spending limits (per-transaction/daily/monthly/lifetime), card transaction lifecycle (on-chain debit/credit with withdrawal and transfer), and 3DS authentication (OTP via SMS and webhook in-app confirmation approve/decline)."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Card Management

## Overview

The Wirex BaaS card system provides Visa virtual, plastic, and metal card issuance, lifecycle management, secure details retrieval, configurable limits, an on-chain transaction flow (including withdrawal and transfer), and 3DS authentication handling (OTP via SMS and in-app confirmation via webhook).

### Required Headers

All card API endpoints require the following headers:

| Header | Description |
|--------|-------------|
| `Authorization` | Bearer token for authentication |
| `X-User-Address` | User's EOA (Externally Owned Account) address, not Smart Wallet address |
| `X-Chain-Id` | Blockchain chain ID |

### Card Types

| Type | Capability Required | Delivery | Activation |
|------|-------------------|----------|------------|
| **Virtual** | `VisaVirtualCard` | Instant (digital) | Auto-activated on issuance |
| **Plastic** | `VisaPlasticCard` | Shipped to address | Manual activation required |
| **Metal** | `VisaMetalCard` | Shipped to address | Manual activation required |

---

## Virtual Card Issuance

| Step | Endpoint | Method |
|------|----------|--------|
| 1. Check fees | `/api/v1/cards/Virtual/fees/{country}` | GET |
| 2. Create invoice | `/api/v2/cards/Virtual/fees/{country}/payment` | POST |
| 3. Issue card | `/api/v2/cards/virtual` | POST |

> **Note:** Fee checking and invoice creation are applicable only if your account manager has advised you to incorporate card fee handling.

## Physical Card Issuance

| Step | Endpoint | Method |
|------|----------|--------|
| 1. Delivery countries | `/api/v1/cards/delivery/countries` | GET |
| 2. Delivery methods | `/api/v1/cards/delivery/methods/{country}` | GET |
| 3. Check fees | `/api/v1/cards/Plastic/fees/{country}` | GET |
| 4. Create invoice | `/api/v2/cards/Plastic/fees/{country}/payment` | POST |
| 5. Issue card | `/api/v2/cards/plastic` | POST |

---

## Card Lifecycle

### Status Flow

**Physical cards:** Requested → NotActivated → Active ↔ Blocked → Closed

**Virtual cards:** Active (auto-activated) ↔ Blocked → Closed

> **WARNING:** Closing a card is **irreversible**. The card cannot be reactivated.

| Status | Description | Applies To |
|--------|-------------|------------|
| `Requested` | Card order placed, production/shipping in progress | Physical only |
| `NotActivated` | Card delivered but not yet activated | Physical only |
| `Active` | Card is active and usable for transactions | Both |
| `Blocked` | Temporarily blocked; can be unblocked | Both |
| `Closed` | Permanently closed; cannot be reactivated | Both |

### Management Endpoints

| Action | Endpoint | Method |
|--------|----------|--------|
| Activate | `/api/v1/cards/{cardId}/activate` | PUT |
| Block | `/api/v1/cards/{cardId}/block` | PUT |
| Unblock | `/api/v1/cards/{cardId}/unblock` | PUT |
| Close | `/api/v1/cards/{cardId}/close` | PUT |
| Change name | `/api/v1/cards/{cardId}/name` | PUT |

---

## Card Details Retrieval (PAN, CVV, PIN)

> **WARNING:** `action_token` expires in **5 minutes** and is single-use per detail type.

Card details require a two-step verification process producing an `action_token`.

### Verification Methods

1. **Signature Verification** (recommended): `POST /api/v1/confirmation/signature/verify` -- uses `action_type` (enum: `GetCardDetails`, `3dsChallenge`, `VerifyPhone`), `message_signature`, and `nonce` (Unix timestamp).
2. **SMS OTP**: `POST /api/v1/confirmation/sms` (uses `action_type`) then `POST /api/v1/confirmation/sms/verify` (uses `session_id`).

### Detail Endpoints (all require `action_token`)

| Detail | Endpoint | Method | Notes |
|--------|----------|--------|-------|
| PAN + Expiry | `/api/v1/cards/{cardId}/details` | POST | |
| CVV | `/api/v1/cards/{cardId}/cvv` | POST | |
| PIN | `/api/v1/cards/{cardId}/pin` | POST | Physical cards only |

---

## Card Limits

### View Limits

```
GET /api/v1/cards/{cardId}
```

Returns `limit` object with `transaction_limit`, `daily_limit`, `daily_usage`, `monthly_limit`, `monthly_usage`, `lifetime_limit`, `lifetime_usage`, and `currency`. A value of `-1` means no limit.

### Update Limits

```
PUT /api/v1/cards/{cardId}/limit
```

Supports `transaction`, `daily`, `monthly`, and `lifetime` limit types. Set to `-1` to disable a limit.

---

## Card Transaction Flow

Card transactions follow an **on-chain debit/credit flow** through the FundsManagement executor.

### Debit (Card Purchase)

1. **Initiated** → Authorization request received from card network
2. **CryptoOut** → Funds debited from user wallet to FundsBuffer (on-chain)
3. **CardOut** → Funds settled to card network
4. **Completed** → Transaction finalized

### Card Withdrawal

| Step | Endpoint | Method |
|------|----------|--------|
| Estimate | `/api/v1/cards/{cardId}/withdrawal/estimate` | POST |
| Execute | `/api/v1/cards/{cardId}/withdrawal/execute` | POST |

### Card Transfer

| Step | Endpoint | Method |
|------|----------|--------|
| Estimate | `/api/v1/cards/{cardId}/transfer/estimate` | POST |
| Execute | `/api/v1/cards/{cardId}/transfer/execute` | POST |

### Credit (Refund/Top-up)

1. **Initiated** → Credit request received
2. **CardIn** → Funds received from card network
3. **CryptoIn** → Funds credited to user wallet (on-chain)
4. **Completed** → Transaction finalized

---

## 3DS Authentication

Wirex supports two 3DS authentication methods:

### Method 1: OTP via SMS

The card network sends a one-time password directly to the cardholder's registered phone number. This method requires **no backend involvement** from the partner -- the OTP is delivered and verified entirely by the card network and the cardholder.

### Method 2: In-App Confirmation via Webhook

When a 3DS challenge is triggered, Wirex sends a webhook and waits for approval.

1. Wirex sends `POST /v2/webhooks/3ds` with transaction details
2. Partner displays approval UI to user
3. Partner calls approve or decline endpoint
4. If no response before timeout, request is automatically declined

### In-App Confirmation Endpoints

| Action | Endpoint | Method |
|--------|----------|--------|
| Get pending | `/api/v1/cards/3ds/requests` | GET |
| Approve | `/api/v1/cards/3ds/requests/{transactionId}/approve` | POST |
| Decline | `/api/v1/cards/3ds/requests/{transactionId}/decline` | POST |

---

## Webhooks

| Webhook | Endpoint | Trigger |
|---------|----------|---------|
| Card status | `/v2/webhooks/cards` | Card status changes |
| Card limits | `/v2/webhooks/card-limits` | Limit or usage updates |
| Activities | `/v2/webhooks/activities` | Card transactions |
| 3DS | `/v2/webhooks/3ds` | 3DS authentication requests |

---

## Quick Reference

| Action | Endpoint | Method |
|--------|----------|--------|
| List all cards | `/api/v1/cards` | GET |
| Get card details | `/api/v1/cards/{cardId}` | GET |
| Issue virtual card | `/api/v2/cards/virtual` | POST |
| Issue plastic card | `/api/v2/cards/plastic` | POST |
| Issue metal card | `/api/v2/cards/metal` | POST |
| Activate card | `/api/v1/cards/{cardId}/activate` | PUT |
| Block card | `/api/v1/cards/{cardId}/block` | PUT |
| Unblock card | `/api/v1/cards/{cardId}/unblock` | PUT |
| Close card | `/api/v1/cards/{cardId}/close` | PUT |
| Change card name | `/api/v1/cards/{cardId}/name` | PUT |
| Get PAN | `/api/v1/cards/{cardId}/details` | POST |
| Get CVV | `/api/v1/cards/{cardId}/cvv` | POST |
| Get PIN | `/api/v1/cards/{cardId}/pin` | POST |
| Update limits | `/api/v1/cards/{cardId}/limit` | PUT |
| Withdrawal estimate | `/api/v1/cards/{cardId}/withdrawal/estimate` | POST |
| Withdrawal execute | `/api/v1/cards/{cardId}/withdrawal/execute` | POST |
| Transfer estimate | `/api/v1/cards/{cardId}/transfer/estimate` | POST |
| Transfer execute | `/api/v1/cards/{cardId}/transfer/execute` | POST |
| 3DS requests | `/api/v1/cards/3ds/requests` | GET |
| Approve 3DS | `/api/v1/cards/3ds/requests/{id}/approve` | POST |
| Decline 3DS | `/api/v1/cards/3ds/requests/{id}/decline` | POST |

---

## References

- [Card API Reference](references/REFERENCE.md) -- Complete request/response schemas, error codes, field validation patterns, and JavaScript examples
- See [webhook payloads](../wirex-baas-webhooks/references/REFERENCE.md) for complete webhook payload examples
