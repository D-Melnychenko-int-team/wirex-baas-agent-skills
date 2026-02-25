# Wirex BaaS Transfers — SEPA & ACH Banking Reference

Detailed endpoint reference for SEPA (EUR) and ACH (USD) bank transfers, including bank detail activation, transfer estimation, execution, capabilities, and webhooks.

## Table of Contents

- [SEPA Bank Details](#sepa-bank-details)
- [SEPA Transfer Estimate](#sepa-transfer-estimate)
- [SEPA Transfer Execute](#sepa-transfer-execute)
- [ACH Bank Details](#ach-bank-details)
- [ACH Transfer Estimate](#ach-transfer-estimate)
- [ACH Transfer Execute](#ach-transfer-execute)
- [Capability Requirements](#capability-requirements)
- [Activity Webhook](#activity-webhook)
- [Error Codes](#error-codes)

---

## SEPA Bank Details

SEPA bank accounts are **auto-provisioned** upon user verification. There is no activation call needed. Simply retrieve the account details once the `SepaAccount` capability is `Active`.

### Get Bank Accounts

**GET /api/v1/bank/accounts**

Retrieves all bank accounts for the user, including SEPA details (IBAN and BIC).

**Request Headers:**

| Header         | Required | Description                        |
|---------------|----------|------------------------------------|
| Authorization  | Yes      | Bearer `{access_token}`           |
| Content-Type   | Yes      | `application/json`                 |
| X-User-Address | Yes      | The user's EOA wallet address      |
| X-Chain-Id     | Yes      | The blockchain chain ID            |

**Query Parameters:**

| Parameter   | Type    | Default | Description              |
|------------|---------|---------|--------------------------|
| page_number | integer | 0       | Page index (0-indexed)   |
| page_size   | integer | 25      | Items per page           |

**Response (200 OK):**

```json
{
  "accounts": [
    {
      "id": "{account_id}:{details_id}",
      "account_type": "Sepa",
      "status": "Active",
      "account_holder": "John Doe",
      "currency": "EUR",
      "details": {
        "iban": "GB29NWBK60161331926819",
        "bic": "TRWIGB2L"
      }
    }
  ]
}
```

The `id` field uses a composite `{account_id}:{details_id}` format. Use this composite ID as the `account_id` in transfer estimate and execute requests.

**Account Statuses:** `Pending` (provisioning), `Active` (ready), `Blocked` (suspended), `Closed` (terminated).

### Bank Account Webhook

**Endpoint:** `POST {webhook_url}/webhook/accounts/fiat`

Triggered when a bank account is created or details change.

**`change_type` values:** `Created`, `DetailsChanged`

---

## SEPA Transfer Estimate

### POST /api/v2/bank/transfer/estimate

Estimate the cost and exchange rate for a SEPA transfer before executing it.

**Request Headers:**

| Header         | Required | Description                        |
|---------------|----------|------------------------------------|
| Authorization  | Yes      | Bearer `{access_token}`           |
| Content-Type   | Yes      | `application/json`                 |
| X-User-Address | Yes      | The user's EOA wallet address      |
| X-Chain-Id     | Yes      | The blockchain chain ID            |

**Request Body:**

```json
{
  "account_id": "{account_id}:{details_id}",
  "amount": 100.00,
  "tokens": ["0x5c55F314624718019A326F16a62A05D6C6d8C8A2"],
  "recipient": {
    "first_name": "Jane",
    "last_name": "Smith"
  },
  "recipient_account": {
    "iban": "DE89370400440532013000",
    "bic": "COBADEFFXXX"
  },
  "reference": "Invoice 12345"
}
```

For company recipients, use `company_name` instead of `first_name`/`last_name`:

```json
{
  "account_id": "{account_id}:{details_id}",
  "amount": 500.00,
  "tokens": ["0x5c55F314624718019A326F16a62A05D6C6d8C8A2"],
  "recipient": {
    "company_name": "Acme GmbH"
  },
  "recipient_account": {
    "iban": "DE89370400440532013000",
    "bic": "COBADEFFXXX"
  }
}
```

**Request Fields:**

| Field                     | Type     | Required | Description                                              |
|---------------------------|----------|----------|----------------------------------------------------------|
| account_id                | string   | Yes      | Composite ID in `{account_id}:{details_id}` format      |
| amount                    | number   | Yes      | Transfer amount in EUR                                   |
| tokens                    | string[] | No       | Token contract addresses; omit for all available tokens  |
| recipient.first_name      | string   | No*      | Recipient first name (individual)                        |
| recipient.last_name       | string   | No*      | Recipient last name (individual)                         |
| recipient.company_name    | string   | No*      | Recipient company name (business)                        |
| recipient_account.iban    | string   | Yes      | Recipient IBAN                                           |
| recipient_account.bic     | string   | Yes      | Recipient BIC/SWIFT code                                 |
| reference                 | string   | No       | Payment memo/reference (max 140 chars)                   |

*Either (`first_name` + `last_name`) or `company_name` is required.

**Response (200 OK):**

```json
{
  "id": "uuid-estimation-id",
  "expires_at": 1704110400,
  "amount": 100.00,
  "currency": "EUR",
  "estimated_amounts": [
    {
      "amount": 109.41,
      "precise_amount": "109410000000000000000",
      "token_address": "0x5c55F314624718019A326F16a62A05D6C6d8C8A2",
      "token_symbol": "WEUR",
      "rate": 1.0
    }
  ]
}
```

**Response Fields:**

| Field                                    | Type   | Description                                          |
|------------------------------------------|--------|------------------------------------------------------|
| id                                       | string | Estimation ID (use in execute step)                  |
| expires_at                               | number | Unix timestamp when estimate expires                 |
| amount                                   | number | The requested transfer amount                        |
| currency                                 | string | Transfer currency (EUR)                              |
| estimated_amounts                        | array  | Array of per-token quote objects                     |
| estimated_amounts[].amount               | number | Human-readable token amount to debit                 |
| estimated_amounts[].precise_amount       | string | Wei-denominated precise amount                       |
| estimated_amounts[].token_address        | string | Token contract address                               |
| estimated_amounts[].token_symbol         | string | Token symbol (e.g., WEUR)                            |
| estimated_amounts[].rate                 | number | Exchange rate (token per EUR)                        |

---

## SEPA Transfer Execute

### POST /api/v1/bank/transfer

Execute a SEPA transfer using the estimation ID or a direct amount.

**Request Headers:**

| Header         | Required | Description                        |
|---------------|----------|------------------------------------|
| Authorization  | Yes      | Bearer `{access_token}`           |
| Content-Type   | Yes      | `application/json`                 |
| X-User-Address | Yes      | The user's EOA wallet address      |
| X-Chain-Id     | Yes      | The blockchain chain ID            |

**Request Body (with estimation):**

```json
{
  "account_id": "uuid-bank-account-id",
  "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606",
  "estimation_id": "uuid-estimation-id",
  "recipient": {
    "first_name": "Jane",
    "last_name": "Smith"
  },
  "recipient_account": {
    "iban": "DE89370400440532013000",
    "bic": "COBADEFFXXX"
  }
}
```

**Request Body (with direct amount):**

```json
{
  "account_id": "uuid-bank-account-id",
  "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606",
  "amount": "100.00",
  "recipient": {
    "first_name": "Jane",
    "last_name": "Smith"
  },
  "recipient_account": {
    "iban": "DE89370400440532013000",
    "bic": "COBADEFFXXX"
  }
}
```

**Request Fields:**

| Field          | Type   | Required | Description                                          |
|----------------|--------|----------|------------------------------------------------------|
| account_id     | string | Yes      | The SEPA bank account ID                             |
| token_address  | string | Yes      | WEUR token contract address                          |
| estimation_id  | string | No*      | Estimation ID from the estimate step                 |
| amount         | string | No*      | Direct amount (if not using estimation)              |
| recipient      | object | Yes      | Recipient name details (same as estimate)            |
| recipient_account | object | Yes   | Recipient bank details (same as estimate)            |

*Either `estimation_id` or `amount` is required.

**Response (200 OK):**

```json
{
  "id": "uuid-activity-id"
}
```

The `id` is the activity ID for tracking the transfer progress via webhooks.

---

## ACH Bank Details

### Activate ACH Bank Account

**POST /api/v1/bank/accounts**

Creates ACH bank account credentials (account number and routing number) for the user.

**Request Body:**

```json
{
  "account_type": "Ach"
}
```

**Response (200 OK):**

```json
{
  "details_id": "uuid-details-id"
}
```

After activation, use `GET /api/v1/bank/accounts` to retrieve the full account details (account number, routing number). The response follows the same `accounts[]` structure as SEPA, with `details.account_number` and `details.routing_number`.

---

## ACH Transfer Estimate

### POST /api/v2/bank/transfer/estimate

Estimate the cost and exchange rate for an ACH transfer.

**Request Body:**

```json
{
  "account_id": "{account_id}:{details_id}",
  "amount": 250.00,
  "tokens": ["WUSD"],
  "recipient": {
    "first_name": "Bob",
    "last_name": "Johnson"
  },
  "recipient_account": {
    "account_number": "1234567890",
    "routing_number": "021000021",
    "bank_name": "Chase Bank",
    "legal_address": {
      "line1": "123 Main Street",
      "line2": "Suite 100",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "US"
    }
  }
}
```

**ACH-Specific Request Fields:**

| Field                                    | Type   | Required | Description                      |
|------------------------------------------|--------|----------|----------------------------------|
| recipient_account.account_number         | string | Yes      | Recipient bank account number    |
| recipient_account.routing_number         | string | Yes      | ABA routing number               |
| recipient_account.bank_name              | string | No       | Name of the recipient's bank     |
| recipient_account.legal_address          | object | Yes      | Recipient's legal address        |
| recipient_account.legal_address.line1    | string | Yes      | Street address                   |
| recipient_account.legal_address.line2    | string | No       | Additional address info          |
| recipient_account.legal_address.city     | string | Yes      | City                             |
| recipient_account.legal_address.state    | string | No       | State/province code (required for US) |
| recipient_account.legal_address.zip_code | string | Yes      | Postal/ZIP code                  |
| recipient_account.legal_address.country  | string | Yes      | ISO 3166-1 alpha-2 country code  |

**Response (200 OK):**

Uses the same response format as SEPA estimates:

```json
{
  "id": "uuid-estimation-id",
  "expires_at": 1704110400,
  "amount": 250.00,
  "currency": "USD",
  "estimated_amounts": [
    {
      "amount": 250.00,
      "precise_amount": "250000000000000000000",
      "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
      "token_symbol": "WUSD",
      "rate": 1.0
    }
  ]
}
```

---

## ACH Transfer Execute

### POST /api/v1/bank/transfer

Execute an ACH transfer.

**Request Body:**

```json
{
  "account_id": "{account_id}:{details_id}",
  "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
  "estimation_id": "uuid-estimation-id",
  "recipient": {
    "first_name": "Bob",
    "last_name": "Johnson"
  },
  "recipient_account": {
    "account_number": "1234567890",
    "routing_number": "021000021",
    "bank_name": "Chase Bank",
    "legal_address": {
      "line1": "123 Main Street",
      "city": "New York",
      "state": "NY",
      "zip_code": "10001",
      "country": "US"
    }
  }
}
```

**Response (200 OK):**

```json
{
  "id": "uuid-activity-id"
}
```

The `id` is the activity ID for tracking the transfer progress via webhooks.

---

## Activity Webhook

**Endpoint:** `/v2/webhooks/activities`

SEPA and ACH transfers emit activity events as the transfer progresses through each step.

**Steps:** Initiated → CryptoOut → Review → BankOut → Completed

A transfer can also reach `Failed` or `Cancelled` status at any step.

See [wirex-baas-webhooks reference](../wirex-baas-webhooks/references/REFERENCE.md) for complete activity webhook payloads (event type: `activity.updated`, transfer type: `BankTransfer`).

---

## Error Codes

All errors follow the standard Wirex BaaS error format with nested `error_category`:

```json
{
  "error_reason": "ErrorInvalidField",
  "error_description": "Recipient IBAN is invalid",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  },
  "error_details": [
    { "key": "field", "details": "iban" }
  ]
}
```

### SEPA Error Codes

| HTTP Status | Error Reason | Description |
|-------------|-------------|-------------|
| 400 | `ErrorNotSupported` | SepaAccount capability not active |
| 400 | `ErrorNotSupported` | SepaOut capability not active |
| 400 | `ErrorInvalidField` | Recipient IBAN is invalid |
| 400 | `ErrorInvalidField` | Recipient BIC is invalid |
| 400 | `ErrorExpired` | Estimation ID has expired |
| 400 | `ErrorInvalidField` | Not enough WEUR balance |
| 400 | `ErrorInvalidField` | Transfer exceeds allowed limits |
| 400 | `ErrorNotSupported` | Recipient country not in SEPA zone |

### ACH Error Codes

| HTTP Status | Error Reason | Description |
|-------------|-------------|-------------|
| 400 | `ErrorNotSupported` | AchAccount capability not active |
| 400 | `ErrorNotSupported` | AchOut capability not active |
| 400 | `ErrorInvalidField` | Routing number is invalid |
| 400 | `ErrorInvalidField` | Account number is invalid |
| 400 | `ErrorMissingField` | legal_address is required for ACH |
| 400 | `ErrorExpired` | Estimation ID has expired |
| 400 | `ErrorInvalidField` | Not enough WUSD balance |
| 400 | `ErrorInvalidField` | Transfer exceeds allowed limits |
