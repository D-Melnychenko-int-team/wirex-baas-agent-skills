---
name: wirex-baas-sandbox
description: "Wirex BaaS sandbox testing — simulate real-world scenarios in the development environment. Helper API (ramc.wirexapp.tech) for minting test tokens, simulating SEPA deposits and transfers (complete/revert), ACH customer activation and transfers, and card transactions (POS/EPOS/ATM/credit). Includes sandbox test credentials and token addresses. Interactive docs at ramc.wirexapp.tech/api-docs/."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Sandbox Testing

The Wirex BaaS sandbox environment provides a **Helper API** for simulating real-world financial scenarios without touching production systems. This includes minting test tokens, simulating bank transfers, and triggering card transactions.

## Helper API

| Property | Value |
|----------|-------|
| **Base URL** | `https://ramc.wirexapp.tech` |
| **Interactive Docs** | `https://ramc.wirexapp.tech/api-docs/` |
| **Authentication** | Email-based identification (no Bearer token required for the Helper API) |
| **Availability** | Sandbox only -- not available in production |

The Helper API is separate from the main BaaS API. It uses `email` to identify users rather than Bearer tokens. Each simulation triggers the corresponding webhooks on your registered endpoints.

---

## Sandbox Test Credentials

These credentials are used with the **main BaaS API** (not the Helper API):

| Credential | Value |
|------------|-------|
| `client_id` | `9qgK7xzQirmJgZi9zOamLXQ6dQ7KpUu9` |
| `client_secret` | `BaVKTFYdYdk5urr9fuzRHKEZ3BC-pvhyANaOfDN10r_mW-MTaZ_v4tTA1IFzav6I` |
| `partner_id` | `0x00000000000000000000000000000007` |

### Sandbox Token Addresses (Base Sepolia, Chain ID: 84532)

| Token | Address | Decimals |
|-------|---------|----------|
| WUSD | `0x0774164DC20524Bb239b39D1DC42573C3E4C6976` | 18 |
| WEUR | `0x5c55F314624718019A326F16a62A05D6C6d8C8A2` | 18 |
| USDC | `0x7Af7cDbd557eD302F7538Db1e3d094C8BBcA665c` | 6 |
| USDT | `0x2C6c7c00ACa9B9D8446d107367485079b0471706` | 18 |
| EURC | `0xF70461ffb413981852683657A310892227e3989e` | 6 |

---

## Mint Test Tokens

```
POST /account/retail/mint
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chainId` | string | Yes | `84532` (Base Sepolia) |
| `token` | string | Yes | Token contract address |
| `to` | string | Yes | Recipient wallet address |
| `amount` | string | Yes | Amount (human-readable, not wei) |

**Triggers:** `/v2/webhooks/balances`

---

## SEPA Simulation

| Action | Endpoint | Method |
|--------|----------|--------|
| Deposit | `/bank/sepa/deposit` | POST |
| Get pending | `/bank/sepa/transfers/pending?region={r}&email={e}` | GET |
| Complete | `/bank/sepa/transfer/complete` | POST |
| Revert | `/bank/sepa/transfer/revert` | POST |

- Deposit requires `region` ("GB" or "EEA"), `email`, and `amount` (EUR).
- Complete/revert require `region`, `email`, and `transactionId`.
- **Sandbox behavior:** In sandbox environment, all outbound SEPA transfers remain in pending state indefinitely. Use `complete` or `revert` endpoints to simulate the external banking system processing the transfer.
- **Revert constraint:** The revert endpoint creates an inbound reversal transaction and can only be called after a transfer has been completed (not on pending transfers).
- **Triggers:** `/v2/webhooks/activities` with `type=Sepa`

---

## ACH Simulation

| Action | Endpoint | Method |
|--------|----------|--------|
| Activate customer | `/bank/ach/customer/activate` | POST |
| Deposit | `/bank/ach/deposit` | POST |
| Complete transfer | `/bank/ach/transfer/complete` | POST |
| Revert transfer | `/bank/ach/transfer/revert` | POST |

- Activate requires `email`. Must be called before any ACH operations.
- **ACH account behavior:** In sandbox environment, ACH accounts remain in pending state indefinitely after creation. Call the activate endpoint to simulate the external ACH provider activating the account.
- Deposit requires `email` and `amount` (USD).
- **ACH transfer behavior:** In sandbox environment, all outbound ACH transfers remain in pending state indefinitely. Use `complete` or `revert` endpoints to simulate the external ACH network processing the transfer.
- Complete/revert require `externalId` (activity ID from webhook).
- **Revert behavior:** The revert endpoint creates an inbound reversal transaction that credits the funds back to the user's account.
- **Triggers:** `/v2/webhooks/activities` with `type=AchPush` (direction: Inbound)

---

## Card Transaction Simulation

All card endpoints accept `cardId` (UUID) and `amount` (number).

| Action | Endpoint | Description |
|--------|----------|-------------|
| POS | `/card/transaction/pos` | In-store purchase |
| EPOS | `/card/transaction/epos` | Online purchase / 3DS testing |
| ATM | `/card/transaction/atm` | Cash withdrawal |
| Credit | `/card/transaction/credit` | Refund / cashback (**adds** funds) |

**Triggers:** `/v2/webhooks/activities`, `/v2/webhooks/balances`, `/v2/webhooks/card-limits`

---

## Webhook Trigger Summary

| Simulation | Webhooks Triggered |
|------------|-------------------|
| Mint tokens | `/v2/webhooks/balances` |
| SEPA deposit | `/v2/webhooks/activities` (Sepa, Inbound) |
| SEPA complete | `/v2/webhooks/activities` (Completed) |
| SEPA revert | `/v2/webhooks/activities` (Failed) |
| ACH deposit | `/v2/webhooks/activities` (AchPush, Inbound) |
| ACH complete | `/v2/webhooks/activities` (Completed) |
| ACH revert | `/v2/webhooks/activities` (Failed) |
| Card POS/EPOS/ATM | `/v2/webhooks/activities`, `/v2/webhooks/balances`, `/v2/webhooks/card-limits` |
| Card credit | `/v2/webhooks/activities`, `/v2/webhooks/balances`, `/v2/webhooks/card-limits` |

---

## Quick Start: Testing Workflow

1. **Obtain S2S token** from the main BaaS API using sandbox credentials.
2. **Register a user** via `POST /api/v2/user` on the main BaaS API.
3. **Mint tokens** via the Helper API to fund the user's wallet.
4. **Simulate deposits** (SEPA or ACH) to test bank transfer flows.
5. **Issue a card** via the main BaaS API.
6. **Simulate card transactions** via the Helper API.
7. **Monitor webhooks** on your registered endpoints.
8. **Query activity history** via `GET /api/v1/activity/feed` to verify.

---

## References

- [Sandbox Helper API Reference](references/REFERENCE.md) -- Complete endpoint specifications with all request/response fields, error codes, and JavaScript code examples
