# Wirex BaaS Transfers — Push-to-Card Reference

Detailed reference for Push-to-Card transfers via Visa/Mastercard OCT (Original Credit Transaction) rails, including PCI tokenization, recipient creation, estimation, and execution.

## Table of Contents

- [PCI Environment URLs](#pci-environment-urls)
- [Step 1: Card Tokenization](#step-1-card-tokenization)
- [Step 2: Create Card Recipient](#step-2-create-card-recipient)
- [Step 3: Estimate Transfer](#step-3-estimate-transfer)
- [Step 4: Execute Transfer](#step-4-execute-transfer)
- [Activity Steps](#activity-steps)
- [Capability Requirements](#capability-requirements)
- [Error Codes](#error-codes)

---

## PCI Environment URLs

Card tokenization must be performed against the PCI-compliant card manager service. Use the appropriate URL for your environment:

| Environment | URL                                                                |
|-------------|--------------------------------------------------------------------|
| Sandbox     | `https://wx-acquiring-card-manager-uat.wirexapp.com`               |
| Production  | `https://wx-acquiring-card-manager.wirexapp.com`                   |

All card data (card number, cardholder name) is sent only to the PCI endpoint and never to the main API. The main API only receives tokenized references.

---

## Step 1: Card Tokenization

### POST {pci_url}/b2b/cards/oct?user_id={user_id}

Tokenize a card for use in Push-to-Card transfers. The card number is validated and a secure token is returned.

> **Authentication:** This endpoint requires a **user-scoped token** obtained via [User Token Issuance](../../wirex-baas-auth/SKILL.md#method-2-user-token-issuance). S2S tokens are not supported for this endpoint.

**Query Parameters:**

| Parameter | Required | Description |
|-----------|----------|-------------|
| `user_id` | Yes      | User UUID from `GET /api/v2/user` response (`id` field) |

**Request Headers:**

| Header         | Required | Description                        |
|---------------|----------|------------------------------------|
| Authorization  | Yes      | Bearer `{user_token}` (user-scoped, not S2S) |
| Content-Type   | Yes      | `application/json`                 |
| X-User-Address | Yes      | The user's EOA wallet address      |
| X-Chain-Id     | Yes      | The blockchain chain ID            |

**Request Body:**

```json
{
  "card_number": "4111111111111111",
  "cardholder_name": "JANE SMITH",
  "card_label": "Jane's Visa",
  "is_saved": true,
  "is_third_party": false
}
```

**Request Fields:**

| Field           | Type    | Required | Description                                        |
|-----------------|---------|----------|----------------------------------------------------|
| card_number     | string  | Yes      | Full card number (PAN). Visa or Mastercard only.   |
| cardholder_name | string  | Yes      | Name as printed on the card (uppercase recommended)|
| card_label      | string  | Yes      | Display label for the card                         |
| is_saved        | boolean | Yes      | Whether to save the card for future use            |
| is_third_party  | boolean | Yes      | `true` if the card belongs to someone else         |

**Validations Performed:**

| Validation          | Description                                          |
|--------------------|------------------------------------------------------|
| Luhn check          | Card number must pass the Luhn algorithm             |
| Network check       | Only Visa and Mastercard are supported               |
| Expiration check    | Card must not be expired                             |

**Response (200 OK):**

```json
{
  "token": {
    "value": "tok_abc123def456ghi789",
    "card_pan_last": "1111",
    "card_network": "Visa",
    "card_label": "Jane's Visa",
    "is_third_party": false,
    "created_at": "2025-01-15T10:00:00Z"
  }
}
```

**Response Fields:**

| Field              | Type   | Description                              |
|--------------------|--------|------------------------------------------|
| token.value        | string | Secure token representing the card       |
| token.card_pan_last| string | Last 4 digits of the card number         |
| token.card_network | string | Card network (Visa, Mastercard)          |
| token.card_label   | string | Friendly label                           |
| token.is_third_party | boolean | Whether the card is third-party       |
| token.created_at   | string | ISO 8601 creation timestamp              |

---

## Step 2: Create Card Recipient

### POST /api/v2/recipients

Register the tokenized card as a recipient for transfers.

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
  "first_name": "Jane",
  "last_name": "Smith",
  "is_business": false,
  "type": "Card",
  "currencies": ["USD", "EUR"],
  "card": {
    "card_id": "tok_abc123def456ghi789",
    "card_pan_last": "1111"
  }
}
```

**Request Fields:**

| Field             | Type     | Required | Description                          |
|-------------------|----------|----------|--------------------------------------|
| first_name        | string   | Yes*     | Recipient first name (personal)      |
| last_name         | string   | Yes*     | Recipient last name (personal)       |
| company_name      | string   | Yes*     | Company name (business recipients)   |
| is_business       | boolean  | Yes      | `false` for personal, `true` for business |
| type              | string   | Yes      | Must be `"Card"`                     |
| currencies        | string[] | Yes      | Supported currencies (e.g., `["USD", "EUR"]`) |
| card.card_id      | string   | Yes      | Token value from step 1              |
| card.card_pan_last| string   | Yes      | Last 4 digits of the card            |

*Either (`first_name` + `last_name`) or `company_name` is required.

**Response (201 Created):**

```json
{
  "id": "uuid-recipient-id",
  "personal_info": {
    "first_name": "Jane",
    "last_name": "Smith",
    "is_business": false
  },
  "payment_details": [
    {
      "id": "uuid-payment-details-id",
      "type": "Card",
      "currencies": ["USD", "EUR"],
      "card": {
        "card_id": "tok_abc123def456ghi789",
        "card_pan_last": "1111"
      }
    }
  ]
}
```

Use the `payment_details[].id` as the `external_card_id` in the estimate step.

---

## Step 3: Estimate Transfer

### POST /api/v1/cards/transfer/estimate

Estimate the cost and fees for a Push-to-Card transfer.

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
  "external_card_id": "tok_abc123def456ghi789",
  "currency": "USD",
  "amount": "50.00",
  "tokens": ["WUSD"]
}
```

**Request Fields:**

| Field            | Type     | Required | Description                              |
|------------------|----------|----------|------------------------------------------|
| external_card_id | string   | Yes      | Payment details ID from recipient creation (not the card token directly) |
| currency         | string   | No       | Transfer currency (default: EUR)         |
| amount           | number   | Yes      | Amount to send to the card               |
| tokens           | string[] | Yes      | Token address(es) to quote against       |

**Response (200 OK):**

```json
{
  "estimation_id": "uuid-estimation-id",
  "expires_at": 1704110400,
  "currency": "USD",
  "amount": 50.00,
  "fee_amount": 1.50,
  "estimated_amounts": [
    {
      "amount": 51.50,
      "precise_amount": "51500000000000000000",
      "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
      "token_symbol": "WUSD",
      "rate": 1.0
    }
  ]
}
```

**Response Fields:**

| Field                              | Type   | Description                              |
|------------------------------------|--------|------------------------------------------|
| estimation_id                      | string | Estimation ID (use in execute step)      |
| expires_at                         | number | Unix timestamp when estimate expires     |
| currency                           | string | Transfer currency                        |
| amount                             | number | Amount credited to the card              |
| fee_amount                         | number | Fee charged for the transfer             |
| estimated_amounts                  | array  | Per-token debit amounts                  |
| estimated_amounts[].amount         | number | Human-readable token amount to debit     |
| estimated_amounts[].precise_amount | string | Wei-denominated precise amount           |
| estimated_amounts[].token_address  | string | Token contract address                   |
| estimated_amounts[].token_symbol   | string | Token symbol (WUSD, WEUR)               |
| estimated_amounts[].rate           | number | Exchange rate applied                    |

---

## Step 4: Execute Transfer

### POST /api/v1/cards/transfer

Execute the Push-to-Card transfer using the estimation ID.

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
  "estimation_id": "uuid-estimation-id",
  "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2"
}
```

**Request Fields:**

| Field          | Type   | Required | Description                          |
|----------------|--------|----------|--------------------------------------|
| estimation_id  | string | Yes      | Estimation ID from step 3            |
| token_address  | string | Yes      | WUSD or WEUR token contract address  |

**Response (200 OK):**

```json
{
  "id": "uuid-activity-id"
}
```

The `id` is the activity ID for tracking the transfer progress via webhooks.

---

## Activity Steps

Push-to-Card transfers progress through the following steps:

**Steps:** Initiated → CryptoOut → Review → CardOut → Completed

A transfer can also reach `Failed` or `Cancelled` status at any step.

See [wirex-baas-webhooks reference](../wirex-baas-webhooks/references/REFERENCE.md) for complete activity webhook payloads (event type: `activity.updated`, transfer type: `CardTransfer`).

---

## Error Codes

| HTTP Status | Error Reason | Description |
|-------------|-------------|-------------|
| 400 | `ErrorNotSupported` | CardTransfer capability not active |
| 400 | `ErrorInvalidField` | Card number failed Luhn check |
| 400 | `ErrorNotSupported` | Card is not Visa or Mastercard |
| 400 | `ErrorInvalidField` | Card has expired |
| 400 | `ErrorInvalidField` | Card token is invalid or expired |
| 400 | `ErrorExpired` | Estimation ID has expired |
| 400 | `ErrorInvalidField` | Not enough WUSD/WEUR balance |
| 400 | `ErrorInvalidField` | Transfer exceeds allowed limits |
| 400 | `ErrorNotSupported` | Card network rejected the OCT |
| 404 | `ErrorNotFound` | Card recipient not found |
| 503 | `ErrorConfigurationInvalid` | PCI card manager service is unavailable |

### Common Troubleshooting

| Issue                          | Cause                                     | Resolution                                |
|--------------------------------|-------------------------------------------|-------------------------------------------|
| Tokenization fails             | Invalid card number or unsupported network| Verify card is Visa/Mastercard and passes Luhn |
| Estimation returns high fee    | Cross-currency transfer                   | Use matching currency (USD card with WUSD)|
| OCT rejected by network        | Card issuer restrictions                  | Contact card issuer or try different card  |
| Token expired                  | Time elapsed since tokenization           | Re-tokenize the card                      |
