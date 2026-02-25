---
name: wirex-baas-webhooks
description: "Wirex BaaS webhooks and activity history — receive real-time event notifications and query transaction history. Covers all v2 webhook endpoints (wallets, balances, cards, card-limits, 3ds, activities, recipients, erc-withdrawals), v1 legacy webhooks (users, accounts/fiat), delivery specs (POST JSON, 10s timeout, no automatic retry), and the activity history feed (GET /api/v1/activity/feed with pagination and filters)."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Webhooks & Activity History

Wirex BaaS uses webhooks to notify partners of state changes in real time. This skill covers all webhook endpoints (v2 and v1 legacy), delivery semantics, payload structures, and the activity history feed API.

## Webhook Delivery Semantics

| Property | Value |
|----------|-------|
| **Method** | HTTP POST |
| **Content-Type** | `application/json` |
| **Timeout** | 10 seconds |
| **Retries** | None -- failed deliveries are logged but **not retried** |
| **Authentication** | None -- no auth headers are sent with webhook payloads |

> **Security:** Since no authentication headers are included, implement network-level controls such as **IP allowlisting** or **payload verification** to secure your webhook endpoints.

Your webhook receiver must:

1. Return a **2xx HTTP status** within **10 seconds**.
2. Implement **idempotent handlers** -- the same event may be delivered more than once in edge cases.
3. Offload heavy processing to an **async queue** -- do not block the response while processing business logic.

If the receiver does not respond with 2xx within the timeout window, the delivery is recorded as failed and will not be retried. Monitor your webhook logs and implement a polling fallback using the activity history feed for critical flows.

---

## V2 Webhook Endpoints

All v2 webhooks are delivered to partner-registered URLs. The path suffixes below indicate the event category.

| Endpoint | Purpose |
|----------|---------|
| `/v2/webhooks/wallets` | Wallet creation and status changes (Confirmed, Rejected, Unknown) |
| `/v2/webhooks/balances` | Token balance updates (WUSD, WEUR) |
| `/v2/webhooks/cards` | Card status and data changes |
| `/v2/webhooks/card-limits` | Spending limit configuration and usage updates |
| `/v2/webhooks/3ds` | 3D Secure confirmation requests |
| `/v2/webhooks/activities` | Transaction and activity feed updates |
| `/v2/webhooks/recipients` | Recipient creation and update notifications |
| `/v2/webhooks/erc-withdrawals` | Pending ERC20 withdrawal requests with validity windows |

---

## V1 Legacy Webhook Endpoints

These endpoints are maintained for backward compatibility with earlier integrations.

| Endpoint | Purpose |
|----------|---------|
| `/webhook/users` | User status and verification changes (Applied, Approved, Rejected) |
| `/webhook/accounts/fiat` | Bank account operations and status changes |

---

## Activity Types

The activity system categorizes all financial operations. Each activity has a `type`, `status`, `direction`, and a sequence of `activity_steps`.

### Activity Type Values

| Type | Description |
|------|-------------|
| `Crypto` | On-chain crypto deposit or withdrawal |
| `Sepa` | SEPA bank transfer (EUR) |
| `AchPull` | ACH pull transfer (debit from external bank) |
| `AchPush` | ACH push transfer (credit to external bank) |
| `FasterPayment` | UK Faster Payment |
| `Swift` | SWIFT international wire transfer |
| `Spei` | Mexican SPEI transfer |
| `CardTransaction` | Card purchase, ATM withdrawal, or refund |
| `CardTransfer` | Card-to-wallet or wallet-to-card transfer |
| `CardFeesPayment` | Card-related fee charge |
| `YieldClaim` | Yield or reward claim |
| `Exchange` | Currency exchange operation |

### Activity Status Values

| Status | Meaning |
|--------|---------|
| `Pending` | Activity initiated, awaiting completion |
| `Completed` | Activity finished successfully |
| `Failed` | Activity failed or was reversed |

### Activity Direction Values

| Direction | Meaning |
|-----------|---------|
| `Inbound` | Funds received into the account |
| `Outbound` | Funds sent from the account |
| `Internal` | Internal movement (e.g., card-to-wallet) |

### Activity Step Types

Each activity progresses through a sequence of steps. The `activity_steps` array tracks each step's type, status, and timestamps.

| Step Type | Description |
|-----------|-------------|
| `Initiated` | Activity has been created |
| `CryptoIn` | Crypto deposit detected on-chain |
| `CryptoOut` | Crypto withdrawal submitted on-chain |
| `BankIn` | Incoming bank transfer received |
| `BankOut` | Outgoing bank transfer submitted |
| `Review` | Activity is under compliance review |
| `CardOut` | Card debit executed |
| `CardIn` | Card credit executed (refund) |
| `Reversal` | Transaction reversed |
| `SyntheticWrap` | Tokens wrapped to WUSD/WEUR |
| `SyntheticUnwrap` | Tokens unwrapped from WUSD/WEUR |
| `Completed` | Activity finalized |

---

## Implementation Best Practices

> **WARNING:** Failed webhook deliveries are logged but **NOT retried**. Implement polling fallback for critical flows.

**Webhook handling flow:**

1. Receive POST → validate payload → return `200 OK` immediately (within 10 seconds)
2. Enqueue payload for async processing (SQS, RabbitMQ, Redis Streams)
3. Process idempotently — use the activity `id` or unique event identifier to deduplicate
4. Log every received webhook (timestamp, endpoint, payload hash) for debugging
5. Poll the activity history feed (`GET /api/v1/activity/feed`) as fallback for missed webhooks

---

## Activity History Feed

The activity history endpoint provides a paginated, filterable feed of all user activities. Use it as a fallback for missed webhooks or for building transaction history UIs.

### GET /api/v1/activity/feed

**Headers:**

| Header | Value |
|--------|-------|
| `Authorization` | `Bearer <access_token>` |
| `X-Chain-Id` | Chain ID as string |
| `X-User-Address` | User's EOA address |

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page_number` | integer | No | Page number (1-based, default: 1) |
| `page_size` | integer | No | Items per page (default: 25, max: 100) |
| `types` | string | No | Comma-separated activity types (e.g., `Crypto,Sepa,CardTransaction`) |
| `subject` | string | No | Filter by subject identifier (card ID, wallet address, or account reference) |

**Important:** The `types` and `subject` parameters are **mutually exclusive**. You cannot use both in the same request.

### Subject Types

The `subject` parameter accepts identifiers for specific entity types:

| Subject Type | Description | Example Identifier |
|-------------|-------------|-------------------|
| `Wallet` | Internal smart wallet | Wallet address (`0x...`) |
| `ExternalWallet` | External crypto wallet | External wallet address |
| `Cards` | Issued card | Card UUID |
| `ExternalCard` | External card | External card reference |
| `Merchant` | Merchant entity | Merchant ID |
| `SepaBankAccount` | SEPA bank account | SEPA account reference |
| `AchBankAccount` | ACH bank account | ACH account reference |
| `FasterPaymentBankAccount` | UK Faster Payment account | FP account reference |
| `SwiftBankAccount` | SWIFT bank account | SWIFT account reference |

### Response Structure

The response wraps activities in a pagination envelope:

```json
{
  "activities": [
    {
      "id": "act_abc123",
      "user_address": "0x...",
      "type": "CardTransaction",
      "status": "Completed",
      "direction": "Outbound",
      "source": {
        "type": "Cards",
        "card_id": "card-uuid"
      },
      "destination": {
        "type": "Merchant",
        "merchant_name": "Amazon"
      },
      "source_amount": {
        "amount": "25.50",
        "token_symbol": "WUSD",
        "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2"
      },
      "destination_amount": {
        "amount": "25.50",
        "token_symbol": "WUSD",
        "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2"
      },
      "rate": {
        "ticker": "EUR/WEUR",
        "rate": 1.0
      },
      "activity_steps": [
        {
          "type": "Initiated",
          "status": "Completed",
          "created_at": "2025-03-15T10:30:00Z",
          "completed_at": "2025-03-15T10:30:00Z"
        },
        {
          "type": "CardOut",
          "status": "Completed",
          "created_at": "2025-03-15T10:30:01Z",
          "completed_at": "2025-03-15T10:30:02Z"
        },
        {
          "type": "Completed",
          "status": "Completed",
          "created_at": "2025-03-15T10:30:02Z",
          "completed_at": "2025-03-15T10:30:02Z"
        }
      ],
      "created_at": "2025-03-15T10:30:00Z"
    }
  ],
  "pagination": {
    "page_number": 1,
    "page_size": 25,
    "total_count": 142
  }
}
```

### Filter Examples

Fetch all SEPA activities:

```
GET /api/v1/activity/feed?types=Sepa&page_number=1&page_size=50
```

Fetch activities for a specific card:

```
GET /api/v1/activity/feed?subject=card-uuid&page_number=1&page_size=25
```

Fetch crypto and exchange activities:

```
GET /api/v1/activity/feed?types=Crypto,Exchange&page_number=1&page_size=25
```

### Error Responses

The activity history endpoint returns structured errors for invalid requests:

| Error Reason | Category | Description |
|-------------|----------|-------------|
| `ErrorInvalidField` | `invalid_format` | Invalid UUID format in subject or other fields |
| `ErrorInvalidField` | `invalid_value` | Unrecognized activity type in `types` parameter |
| `ErrorInvalidField` | `mutually_exclusive` | Both `types` and `subject` were provided (they are mutually exclusive) |

Error response body:

```json
{
  "error_reason": "ErrorInvalidField",
  "error_description": "The types and subject parameters are mutually exclusive",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  },
  "error_details": [
    { "key": "issue", "details": "mutually_exclusive" }
  ]
}
```

---

See [references/REFERENCE.md](references/REFERENCE.md) for complete webhook payload examples for every endpoint.
