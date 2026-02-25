# Webhooks & Activity History Reference

Complete webhook payload reference for all Wirex BaaS webhook endpoints. This is the canonical location for webhook payloads — other skills cross-reference this file.

For delivery semantics (POST, 10s timeout, no retry) and the activity history feed API, see [SKILL.md](../SKILL.md).

---

## V2 Webhook Endpoints

### Wallet Webhook -- `/v2/webhooks/wallets`

Fires when a wallet is created or its status changes.

**Payload:**

```json
{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "wallet_name": "Main Wallet",
  "wallet_status": "Confirmed",
  "wallet_type": "Primary",
  "balances": []
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `wallet_address` | string | The on-chain smart wallet address |
| `wallet_name` | string | Human-readable wallet label |
| `wallet_status` | string | Current wallet status |
| `wallet_type` | string | Wallet classification |
| `balances` | array | Current token balances (empty on creation) |

**`wallet_status` Values:**

| Status | Meaning |
|--------|---------|
| `Confirmed` | Wallet successfully deployed and registered on-chain |
| `Rejected` | Wallet deployment or registration failed |
| `Unknown` | Wallet state cannot be determined |

**`wallet_type` Values:**

| Type | Meaning |
|------|---------|
| `Primary` | Main user wallet |
| `Secondary` | Additional user wallet |
| `Global` | Global deposit address wallet (Rhino.fi) |
| `Card` | Dedicated card funding wallet |

---

### Balance Webhook -- `/v2/webhooks/balances`

Fires when a token balance changes for any reason (deposit, withdrawal, card debit, transfer, etc.).

**Payload:**

```json
{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "token_symbol": "WUSD",
  "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
  "balance": 100.00,
  "reference_balance": 100.00,
  "reference_currency": "USD"
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `wallet_address` | string | The wallet whose balance changed |
| `token_symbol` | string | Token symbol (`WUSD` or `WEUR`) |
| `token_address` | string | On-chain token contract address |
| `balance` | number | Current token balance (human-readable) |
| `reference_balance` | number | Equivalent fiat amount |
| `reference_currency` | string | Fiat currency code (`USD` or `EUR`) |

---

### Card Webhook -- `/v2/webhooks/cards`

Fires when a card's status or data changes (creation, activation, blocking, etc.).

**Payload:**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "card_wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "status": "Active",
  "status_reason": "Activated by user",
  "previous_status": "NotActivated",
  "generation": "Gen2",
  "provider": "Wirex",
  "card_data": {
    "name_on_card": "John Doe",
    "payment_system": "Visa",
    "card_number_last_4": "1234",
    "expiry_date": "12/2028",
    "format": "Virtual",
    "card_name": "Main Card"
  },
  "delivery_address": {
    "line_1": "123 Main St",
    "city": "London",
    "country": "GB"
  },
  "created_at": "2025-03-15T10:30:00Z",
  "updated_at": "2025-03-15T10:30:00Z"
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Unique card identifier |
| `card_wallet_address` | string | Card's associated wallet address |
| `status` | string | Card status (Requested, NotActivated, Active, Closed, Blocked) |
| `status_reason` | string | Reason for the current status |
| `previous_status` | string | Previous card status value |
| `generation` | string | Card generation (Gen1, Gen2) |
| `provider` | string | Card provider (Wirex, Bridge) |
| `card_data` | object | Card details (see sub-fields below) |
| `delivery_address` | object (optional) | Physical card delivery address |
| `created_at` | string (ISO 8601) | Card creation timestamp |
| `updated_at` | string (ISO 8601) | Last update timestamp |

**`card_data` Sub-Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `name_on_card` | string | Cardholder name as printed on card |
| `payment_system` | string | Payment network (e.g., Visa) |
| `card_number_last_4` | string | Last 4 digits of the card number |
| `expiry_date` | string | Card expiry date (MM/YYYY) |
| `format` | string | Card format (e.g., Virtual, Physical) |
| `card_name` | string | User-assigned card name |

---

### Card Limits Webhook -- `/v2/webhooks/card-limits`

Fires when card spending limits are updated or usage thresholds change.

**Payload:**

```json
{
  "card_id": "550e8400-e29b-41d4-a716-446655440000",
  "transaction_limit": -1,
  "daily_limit": 1000.00,
  "daily_usage": 250.00,
  "monthly_limit": -1,
  "monthly_usage": 500.00,
  "lifetime_limit": -1,
  "lifetime_usage": 1500.00
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `card_id` | string (UUID) | Card identifier |
| `transaction_limit` | number | Per-transaction limit (-1 = unlimited) |
| `daily_limit` | number | Daily spending limit (-1 = unlimited) |
| `daily_usage` | number | Amount spent today |
| `monthly_limit` | number | Monthly spending limit (-1 = unlimited) |
| `monthly_usage` | number | Amount spent this month |
| `lifetime_limit` | number | Lifetime spending limit (-1 = unlimited) |
| `lifetime_usage` | number | Total amount spent lifetime |

**Note:** A value of `-1` for any limit field means that limit is unlimited (not enforced).

---

### 3DS Webhook -- `/v2/webhooks/3ds`

Fires when a 3D Secure confirmation is required for a card transaction.

**Payload:**

```json
{
  "card_id": "550e8400-e29b-41d4-a716-446655440000",
  "owner": "0x1234567890abcdef1234567890abcdef12345678",
  "transaction_id": "000000000000001",
  "merchant_name": "Amazon",
  "amount": "100.00",
  "currency": "USD",
  "card_last_4": "1234"
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `card_id` | string (UUID) | Card being charged |
| `owner` | string | Card owner's wallet address |
| `transaction_id` | string | Unique transaction identifier |
| `merchant_name` | string | Merchant requesting the charge |
| `amount` | string | Transaction amount |
| `currency` | string | Transaction currency code |
| `card_last_4` | string | Last 4 digits of the card |

---

### Activity Webhook -- `/v2/webhooks/activities`

Fires when a transaction or activity event occurs. This is the most detailed webhook, providing the full activity object.

**Payload:**

```json
{
  "id": "act_abc123def456",
  "user_address": "0x1234567890abcdef1234567890abcdef12345678",
  "type": "Sepa",
  "status": "Completed",
  "direction": "Inbound",
  "source": {
    "type": "SepaBankAccount",
    "account_ref": "GB29NWBK60161331926819"
  },
  "destination": {
    "type": "Wallet",
    "wallet_address": "0x1234567890abcdef1234567890abcdef12345678"
  },
  "source_amount": {
    "amount": "250.00",
    "token_symbol": "WEUR",
    "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606"
  },
  "destination_amount": {
    "amount": "250.00",
    "token_symbol": "WEUR",
    "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606"
  },
  "operations": [
    {
      "hash": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
      "operation_amount": "250.00",
      "transaction_amount": "250.00",
      "rate": "1.0"
    }
  ],
  "activity_steps": [
    {
      "type": "Initiated",
      "status": "Completed",
      "created_at": "2025-03-15T10:30:00Z",
      "completed_at": "2025-03-15T10:30:00Z"
    },
    {
      "type": "BankIn",
      "status": "Completed",
      "created_at": "2025-03-15T10:30:01Z",
      "completed_at": "2025-03-15T10:31:00Z"
    },
    {
      "type": "SyntheticWrap",
      "status": "Completed",
      "created_at": "2025-03-15T10:31:00Z",
      "completed_at": "2025-03-15T10:31:05Z"
    },
    {
      "type": "Completed",
      "status": "Completed",
      "created_at": "2025-03-15T10:31:05Z",
      "completed_at": "2025-03-15T10:31:05Z"
    }
  ],
  "created_at": "2025-03-15T10:30:00Z"
}
```

**Top-Level Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique activity identifier |
| `user_address` | string | User's wallet address |
| `type` | string | Activity type (Crypto, Sepa, AchPull, AchPush, FasterPayment, Swift, Spei, CardTransaction, CardTransfer, CardFeesPayment, YieldClaim, Exchange) |
| `status` | string | Overall status (Pending, Completed, Failed) |
| `direction` | string | Fund flow direction (Inbound, Outbound, Internal) |
| `source` | object | Source entity |
| `destination` | object | Destination entity |
| `source_amount` | object | Amount debited from source |
| `destination_amount` | object | Amount credited to destination |
| `operations` | array | On-chain operation details |
| `activity_steps` | array | Ordered sequence of processing steps |
| `created_at` | string (ISO 8601) | Activity creation timestamp |

**Source/Destination Object:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Entity type (Wallet, ExternalWallet, Cards, Merchant, SepaBankAccount, AchBankAccount, etc.) |
| `wallet_address` | string | Wallet address (when type is Wallet or ExternalWallet) |
| `card_id` | string | Card UUID (when type is Cards) |
| `merchant_name` | string | Merchant name (when type is Merchant) |
| `account_ref` | string | Bank account reference (when type is a bank account) |

**Amount Object:**

| Field | Type | Description |
|-------|------|-------------|
| `amount` | string | Human-readable amount |
| `token_symbol` | string | Token symbol (WUSD, WEUR) |
| `token_address` | string | On-chain token contract address |

**Operations Object:**

| Field | Type | Description |
|-------|------|-------------|
| `hash` | string | On-chain transaction hash |
| `operation_amount` | string | Amount for this specific operation |
| `transaction_amount` | string | Total transaction amount |
| `rate` | string | Exchange rate applied (if any) |

**Activity Steps Object:**

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | Step type (Initiated, CryptoIn, CryptoOut, BankIn, BankOut, Review, CardOut, CardIn, Reversal, SyntheticWrap, SyntheticUnwrap, Completed) |
| `status` | string | Step status (Pending, Completed, Failed) |
| `created_at` | string (ISO 8601) | Step creation timestamp |
| `completed_at` | string (ISO 8601) | Step completion timestamp (null if pending) |

---

### ERC Withdrawal Webhook -- `/v2/webhooks/erc-withdrawals`

Fires when a pending ERC20 withdrawal request is created. Includes the validity window for execution.

**Payload:**

```json
{
  "account_address": "0x1234567890abcdef1234567890abcdef12345678",
  "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
  "to_address": "0xabcdef1234567890abcdef1234567890abcdef12",
  "amount": "1000000000000000000",
  "valid_after": 1700100000,
  "valid_before": 1700186400,
  "hash": "0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba",
  "call_data": "0x..."
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `account_address` | string | Sender's smart wallet address |
| `token_address` | string | ERC20 token being withdrawn |
| `to_address` | string | Destination address |
| `amount` | string | Raw amount (18 decimals for WUSD/WEUR) |
| `valid_after` | integer | Unix timestamp after which execution is permitted |
| `valid_before` | integer | Unix timestamp after which the request expires |
| `hash` | string | Request hash for identification and execution |
| `call_data` | string | Encoded transaction data for on-chain execution |

**Note:** The withdrawal can only be executed between `valid_after` and `valid_before`. Attempting to execute outside this window will revert.

---

### Recipients Webhook -- `/v2/webhooks/recipients`

Fires when a recipient is created or updated.

**Payload:**

```json
{
  "id": "rcp_abc123",
  "personal_info": {
    "first_name": "John",
    "last_name": "Doe",
    "is_business": false
  },
  "payment_details": [
    {
      "id": "pd_abc123",
      "type": "Sepa",
      "currencies": ["EUR"],
      "sepa": {
        "iban": "GB29NWBK60161331926819",
        "bic": "NWBKGB2L"
      }
    }
  ]
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Unique recipient identifier |
| `personal_info` | object | Recipient personal information |
| `personal_info.first_name` | string | Recipient first name |
| `personal_info.last_name` | string | Recipient last name |
| `personal_info.is_business` | boolean | Whether this is a business recipient |
| `payment_details` | array | Payment methods for this recipient |

**`payment_details` Item Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `id` | string (UUID) | Payment detail identifier |
| `type` | string | Payment type (see supported types below) |
| `currencies` | array | Supported currency codes |

**Supported `payment_details` Types:**

Crypto, Sepa, FasterPayment, Ach, Swift, Spei, Card, Pix, Imps, Instapay, BiFast, Nip, FpsHk

Each type includes type-specific sub-fields (e.g., `sepa.iban`, `sepa.bic` for Sepa; `crypto.address`, `crypto.network` for Crypto; `ach.routing_number`, `ach.account_number`, `ach.bank_name`, `ach.legal_address` for Ach).

---

## V1 Legacy Webhook Endpoints

### Users Webhook -- `/webhook/users`

Fires when a user's profile status or verification status changes.

**Payload:**

```json
{
  "event": "user.verification.updated",
  "user_id": "usr_abc123",
  "owner": "0x1234567890abcdef1234567890abcdef12345678",
  "status": "Approved",
  "verification": {
    "status": "Approved",
    "level": "SDD"
  },
  "timestamp": "2025-03-15T10:30:00Z"
}
```

**`status` Values:**

| Status | Meaning |
|--------|---------|
| `Applied` | User has submitted their application |
| `Approved` | User verification passed |
| `Rejected` | User verification failed |

---

### Fiat Accounts Webhook -- `/webhook/accounts/fiat`

Fires when a bank account status changes (creation, activation, deactivation).

**Payload:**

```json
{
  "event": "account.fiat.updated",
  "user_id": "usr_abc123",
  "account_type": "SepaBankAccount",
  "account_ref": "GB29NWBK60161331926819",
  "status": "Active",
  "currency": "EUR",
  "timestamp": "2025-03-15T10:30:00Z"
}
```

**Field Reference:**

| Field | Type | Description |
|-------|------|-------------|
| `event` | string | Event type identifier |
| `user_id` | string | User identifier |
| `account_type` | string | Bank account type (SepaBankAccount, AchBankAccount, FasterPaymentBankAccount) |
| `account_ref` | string | Bank account reference or IBAN |
| `status` | string | Account status (Active, Inactive, Pending) |
| `currency` | string | Account currency code |
| `timestamp` | string (ISO 8601) | Event timestamp |

