# Card API Reference

Reference for Wirex BaaS retail card endpoints. Base URLs: sandbox `https://api-baas.wirexapp.tech`, production `https://api-baas.wirexapp.com`.

---

## Table of Contents

- [Required Headers](#required-headers)
- [Card Listing and Details](#card-listing-and-details)
- [Card Order Fees and Delivery](#card-order-fees-and-delivery)
- [Card Issuance](#card-issuance)
- [Card Lifecycle Management](#card-lifecycle-management)
- [Verification and Confirmation](#verification-and-confirmation)
- [Secure Card Details Retrieval](#secure-card-details-retrieval)
- [Card Limits](#card-limits)
- [Card Top-Up](#card-top-up)
- [3DS Authentication](#3ds-authentication)
- [Webhook Payloads](#webhook-payloads)
- [Error Codes](#error-codes)
- [Field Validation Patterns](#field-validation-patterns)

---

## Required Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | `Bearer {token}` (S2S token, or user-scoped token) |
| `X-Chain-Id` | Yes | EIP-155 chain ID (`8453` Base, `84532` Base Sepolia) |
| `X-User-Wallet` | With an S2S token | User's EOA address, not the Smart Wallet. Provide exactly one of `X-User-Wallet`, `X-User-Email`, `X-User-Id`. Not needed with a user-scoped token |

```
Authorization: Bearer {token}
X-User-Wallet: 0x1234...abcd
X-Chain-Id: 8453
```

---

## Card Listing and Details

### List Cards

```
GET /api/v1/cards
```

| Query | Type | Description |
|-------|------|-------------|
| `page_number` | integer | Page number |
| `page_size` | integer | Page size (default 25) |
| `sort` | string | `name` (ascending, default) or `usage` (descending usage) |

`GET /api/v3/cards` returns the same list across **every chain** the user holds a card on; `GET /api/v3/cards/{cardId}` reads one card the same way. Same query parameters and `CardResponse` shape; `chain_id` names each entry's chain.

**Response `200`:**

```json
{
  "data": [
    {
      "id": "64120850-73a1-4df5-a074-d463258c9deb",
      "correlation_id": "64120850-73a1-4df5-a074-d463258c9deb",
      "card_wallet_address": "0xAAFF0821A09A1Aac28B72dD3Ff410A7ea5FEb874",
      "status": "Active",
      "status_reason": "",
      "previous_status": "NotActivated",
      "generation": "Gen2",
      "provider": "Wirex",
      "chain_id": 8453,
      "limit": {
        "daily_limit": 10000.00,
        "daily_limit_precise": "10000000000000000000000",
        "daily_usage": 250.00,
        "daily_usage_precise": "250000000000000000000",
        "decimals": 18,
        "currency": "USD"
      },
      "allowed_actions": [
        { "type": "Block", "relative_path": "/api/v1/cards/:cardId/block" },
        { "type": "Close", "relative_path": "/api/v1/cards/:cardId/close" },
        { "type": "SetLimit", "relative_path": "/api/v1/cards/:cardId/limit" },
        { "type": "GetDetails", "relative_path": "/api/v1/cards/:cardId/details" },
        { "type": "GetCvv", "relative_path": "/api/v1/cards/:cardId/cvv" }
      ],
      "card_data": {
        "card_name": "My Card",
        "name_on_card": "Alex Grey",
        "card_number_last_4": "0333",
        "expiry_date": "12/2027",
        "payment_system": "Visa",
        "format": "Virtual"
      },
      "created_at": "2024-01-01T10:00:00Z",
      "updated_at": "2024-01-01T10:05:00Z"
    }
  ]
}
```

| Field | Description |
|-------|-------------|
| `id` | Card ID (use as `{cardId}`) |
| `correlation_id` | The id the issuance order returned; stays on the card after the issuer re-keys it |
| `status` | `Requested`, `NotActivated`, `Active`, `Closed`, `Blocked` |
| `generation` | `Gen1` or `Gen2` |
| `provider` | `Wirex` (Visa rail) or `Bridge` |
| `chain_id` | EIP-155 chain the card belongs to (Bridge: the funding wallet's chain) |
| `funding_token`, `issuer_spender_address` | Present only for a card funded by its own wallet (Bridge rail) |
| `balances[]` | Optional per-token balances (`token_address`, `token_symbol`, `balance`, `reference_balance`, `reference_currency`, `is_active`) |
| `delivery_address` | Optional, for physical cards |
| `limit.*_precise` | Base units as decimal string scaled by `limit.decimals` (18) |
| `card_data.format` | `Virtual`, `Plastic`, `Metal` |
| `card_data.card_number_first_4` | Only while status is `Requested` or `NotActivated` |
| `card_data.card_number_last_4`, `expiry_date` (`MM/YYYY`) | Only when status is not `Requested`/`NotActivated` |

`allowed_actions[].type` values: `Activate`, `Block`, `Unblock`, `Close`, `SetLimit`, `GetDetails`, `GetCvv`, `GetPin`, `SetActiveBalance`.
> Note: docs differ. The guide table lists the first eight; `SetActiveBalance` appears only in the `GET /api/v1/cards` reference enum.

### Get Single Card

```
GET /api/v1/cards/{cardId}
```

Returns the same card object as one list item, including the `limit` object (see [Card Limits](#card-limits)). Note: the API reference page for this endpoint documents a response schema of `card_number` / `expiry_date`, which conflicts with the guides; the guides (and the card list) show the full card object, so use that shape.

---

## Card Order Fees and Delivery

> Fee endpoints apply only if your account manager advised fee handling. If fees are not enforced, they return `400` with `error_details: [{"key":"request","details":"Card fees are not enforced"}]`; skip fee steps and issue the card directly.

### Get Order Fees

```
GET /api/v1/cards/{type}/fees/{country}
```

`{type}`: `virtual`, `plastic`, `metal` (case-insensitive). `{country}`: ISO 3166-1 alpha-2.

```json
{
  "currency": "USD",
  "order_fee": 9.99,
  "estimated_payment_amounts": [
    {
      "amount": 10.05,
      "precise_amount": "10050000",
      "token_address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
      "token_symbol": "USDC",
      "rate": 0.9940
    }
  ]
}
```

### Delivery Countries

```
GET /api/v1/cards/delivery/countries
```

Response: array of country codes, e.g. `["GB", "DE", "FR"]`.

### Delivery Methods

```
GET /api/v1/cards/delivery/methods/{country}
```

```json
[
  {
    "fee": 15.00,
    "currency": "USD",
    "provider": "DHL",
    "estimated_payment_amounts": [
      { "amount": 15.10, "precise_amount": "15100000", "token_address": "0xA0b8...", "token_symbol": "USDC", "rate": 0.9934 }
    ]
  }
]
```

Pass the selected `provider` as `delivery_provider` when creating the invoice and issuing a physical card.

### Card Order Configuration (v3)

```
GET /api/v3/cards/config
```

```json
{
  "formats": [
    {
      "format": "Virtual",
      "offerings": [
        { "payment_system": "Visa", "designs": ["WirexBlack", "WirexBlue"], "card_programs": ["WIREX_ATM_EU"], "countries": ["GB", "DE", "FR"] }
      ]
    }
  ]
}
```

`format`: `Virtual`, `Plastic`, `Metal`. A format with nothing configured returns an empty `offerings` array. A market with two designs on different programs appears as two offerings over the same countries: filter by country and union the results.

---

## Card Issuance

All issue endpoints return `200` with `{ "id": "<card id>" }`; the card starts `Requested` and moves to `NotActivated` once processed. Check capabilities first: `GET /api/v2/user` -> `capabilities[]` (`VisaVirtualCard`, `VisaPlasticCard`, `VisaMetalCard`, `BridgeVirtualCard`, `BridgePlasticCard`; status `Active`, `ActivationNotStarted`, `InProgress`, `NotFulfilled`, `NotRequired`, `NotAvailable`; the guide lists only `Active`, `NotFulfilled`, `NotAvailable`).

### v1 -- External Fee

1. Invoice: `POST /api/v1/cards/{type}/fees/{country}/payment` with `{ "token_address": "0x...", "delivery_provider": "DHL" }` (`delivery_provider` required for physical). Response: `recipient_address` and `payment_amount` (`amount`, `precise_amount`, `token_address`, `token_symbol`, `rate`); **no** `delivery_id`.
2. Pay `payment_amount.precise_amount` of `payment_amount.token_address` to `recipient_address` on-chain; keep the tx hash.
3. Issue: `POST /api/v1/cards/virtual`, `/api/v1/cards/plastic`, `/api/v1/cards/metal`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `payment_transaction_hash` | string | When fees enforced | Hash of the fee transfer |
| `delivery_address` | object | Physical only | See [Address Fields](#address-fields) |
| `delivery_provider` | string | No | Courier provider |
| `card_name` | string | No | Display name (1-50 chars) |
| `name_on_card` | string | No | Printed name (2-26 chars per guide; not enforced by the API, see Field Validation Patterns) |

### v2 -- Direct Fee

1. Invoice: `POST /api/v2/cards/{type}/fees/{country}/payment` (same body). Response: `delivery_id` (integer), `recipient_address`, `payment_amount`.
2. Issue: `POST /api/v2/cards/virtual`, `/api/v2/cards/plastic`, `/api/v2/cards/metal`. Wirex debits the fee automatically (cardholder's on-chain balance; under External Authorization, your Master Account).

```json
{
  "delivery_id": 12345,
  "delivery_provider": "DHL",
  "name_on_card": "Alex Grey",
  "delivery_address": { "line1": "10 Downing Street", "city": "London", "zip_code": "SW1A 2AA", "country": "GB" }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `delivery_id` | integer | When fees enforced | From the invoice. Missing or `0` returns `400 "Delivery ID is required and must be positive"`. There is no `invoice_id` field |
| `delivery_address` | object | Physical only | Omit for virtual |
| `delivery_provider` | string | No | Courier provider |
| `card_name` | string | No | 1-50 chars |
| `name_on_card` | string | No | 2-26 chars per guide (not enforced by the API, see Field Validation Patterns) |

### v3 -- Bridge Rail and Configurable Issuance

Fee invoice is the v2 call (no v3 invoice endpoint). Issue on a per-format path (no `{type}`): `POST /api/v3/cards/virtual`, `/api/v3/cards/plastic`, `/api/v3/cards/metal`. On-chain integrations only (not External Authorization).

All v2 fields plus:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `design` | string | No | One of the company's designs for the format (from `GET /api/v3/cards/config`); omitted = issuer default |
| `card_program` | string | No | Program (carries cash-withdrawal terms); omitted = first program configured for the format and billing country |
| `payment_system` | string | No | `Visa` or `MasterCard`; other values return `400 ErrorGeneral` |
| `card_wallet_address` | string | Conditional | Required when the order resolves to Bridge, rejected when it resolves to Visa, always rejected for metal |

Rail resolution: Visa is tried first (`VisaVirtualCard`/`VisaPlasticCard` `Active`); the order resolves to Bridge only if the Bridge capability is `Active` and Visa is not. Sending `card_wallet_address` does not request Bridge.

| | Visa rail | Bridge rail |
|---|---|---|
| `card_wallet_address` | Omit | Required: a confirmed on-chain wallet of type `Card` |
| Funded from | Cardholder's primary wallet on the request chain | The named card wallet on its own chain |
| Card `chain_id` | Session `X-Chain-Id` | The card wallet's chain |

Bridge funding-wallet errors (`400`, `card_wallet_address` in `error_details`): `ErrorMissingField` (omitted on Bridge), `ErrorInvalidField` (not a non-zero address, or sent on a Visa order), `ErrorGeneral` (sent on metal), `ErrorNotFound` (not a `Card` wallet you hold), `ErrorNotSupported` (implementation rejected on-chain), `ErrorNotYetValid` (not yet confirmed on-chain; wait for the wallet registration webhook `Confirmed`).

### Address Fields

| Field | Required | Validation |
|-------|----------|------------|
| `line1` | Yes | `^[A-Za-z0-9&.,'’\-/() :+#]{2,100}$` |
| `line2` | No | same as `line1` |
| `city` | Yes | `^[A-Za-z\s\-'.]{2,100}$` (no digits) |
| `state` | No | `^[A-Za-z][A-Za-z\s\-']{1,99}$` |
| `zip_code` | Yes | `^[A-Za-z0-9\s\-]{3,12}$` -- always required; use a placeholder such as `"00000"` where the country has no postal code |
| `country` | Yes | `^[A-Z]{2}$` |

A missing field returns `400 ErrorMissingField`, a bad format `400 ErrorInvalidField` (field named in `error_details`, e.g. `delivery_address.zip_code`). If platform checks pass but the card processor rejects the order, the call returns `400 "Request failed due to external validation failure"`, no card is created and no webhook is sent.

---

## Card Lifecycle Management

```
Requested -> NotActivated -> Active <-> Blocked -> Closed
```

| Action | Allowed in | Refused in, with |
|--------|-----------|------------------|
| Activate | `NotActivated` | `Requested`: `Card is not issued yet`; otherwise `Card is already activated` |
| Block | `Active` | `Requested`/`NotActivated`/`Closed`: `Card is not active`; `Blocked`: `Card is already blocked` |
| Unblock | `Blocked` | otherwise `Card is not blocked` |
| Close | `Active`, `Blocked` | `Requested`/`NotActivated`: `Card status does not allow closing`; `Closed`: `Card is already closed` |
| Change limit | `Active` | `Card status does not allow limit changes` |
| Get details, CVV, PIN | `Active` | `Card is not active` |
| Change name | any status | -- |

Refusals are `400 ErrorInvalidStatus` and name the action in `error_details`.

### Activate Card (Physical Only)

```
PUT /api/v1/cards/{cardId}/activate
```

```json
{ "card_number_last4": "1234", "expiry_date": "12/2027" }
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `card_number_last4` | string | Yes | Last 4 digits of the card number |
| `expiry_date` | string | Yes | `MM/YYYY` |

Response `200`, empty.

### Block / Unblock / Close

```
PUT /api/v1/cards/{cardId}/block
PUT /api/v1/cards/{cardId}/unblock
PUT /api/v1/cards/{cardId}/close
```

No request body; response `200 {}`. Closing is irreversible.

### Change Card Name

```
PUT /api/v1/cards/{cardId}/name
```

```json
{ "name": "For unsafe sites" }
```

`name` must match `^[a-zA-Z0-9\-':+# @]{1,50}$`. Response `200 {}`. Changes only `card_data.card_name`; `name_on_card` is embossed at issuance and cannot be changed.

---

## Verification and Confirmation

Before retrieving PAN, CVV or PIN, obtain an `action_token`.

### Signature Verification

```
POST /api/v1/confirmation/signature/verify
```

Message to sign: `By signing this I confirm that I am executing action {ActionType} at {Nonce}`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action_type` | string | Yes | `GetCardDetails`, `3dsChallenge`, `VerifyPhone` |
| `message_signature` | string | Yes | Signature of the message by the user's wallet |
| `nonce` | integer | Yes | Unix timestamp (seconds) when signed; valid 5 minutes |
| `public_key` | string | XRPL only | Hex public key of the signer; ignored on EVM and Stellar |

```json
{ "action_type": "GetCardDetails", "message_signature": "0x1234abcd...", "nonce": 1710496200 }
```

Response `200`: `{ "action_token": "eyJhbGciOi..." }` (a signed JWT). The older `POST /api/v1/confirmation/signature` is obsolete.

Errors: `ErrorMissingField` (`action_type`, `message_signature`, `nonce`), `ErrorInvalidField` (`action_type: invalid_value`, `nonce: expired`, `signature: invalid_signature`).

### Request SMS OTP

```
POST /api/v1/confirmation/sms
```

Body: `{ "action_type": "GetCardDetails" }` (`GetCardDetails`, `3dsChallenge`, `VerifyPhone`). Sends the code to the phone provided during KYC.

```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "attempts_left": 3,
  "expires_at": "2024-01-15T10:05:00Z",
  "code_length": 6,
  "resend_at": "2024-01-15T10:01:00Z"
}
```

### Verify SMS OTP

```
POST /api/v1/confirmation/sms/verify
```

Body: `{ "session_id": "...", "code": "123456" }`. Response `200`: `{ "token": "..." }` -- note the field is `token` here (signature verify returns `action_token`); pass it as `action_token` below.

Errors: `ErrorMissingField` (`code`, `session_id`), `ErrorInvalidField` (`session_id: invalid_uuid`).

---

## Secure Card Details Retrieval

All three endpoints take `{ "action_token": "..." }` in the body and require the card to be `Active`. Token: valid 5 minutes, single use; the docs table also says the same token works for PAN, CVV and PIN (the docs are ambiguous on reuse).

> Call these directly from the client app; proxying cardholder data through your backend is permitted only if the backend is PCI DSS compliant. In browsers, the PCI Compliant SDK `@wirexapp/card-reveal-web` (docs page `retail-pci-sdk-reveal`) renders the values inside Wirex-served iframes so they never reach your page.

### Get PAN and Expiry

```
POST /api/v1/cards/{cardId}/details
```

Response: `{ "card_number": "4111111111111234", "expiry_date": "12/27" }`

### Get CVV

```
POST /api/v1/cards/{cardId}/cvv
```

Response: `{ "cvv": "123" }`

### Get PIN

```
POST /api/v1/cards/{cardId}/pin
```

Response: `{ "pin": "1234" }`. Physical cards only (`ErrorNotSupported`, `card_format: not_physical` otherwise).

### Action Token Errors

| Error Reason | Error Details | Description |
|--------------|---------------|-------------|
| `ErrorInvalidField` | `action_token: invalid_token` | Malformed token |
| `ErrorInvalidField` | `action_token: invalid_claims` | Claims cannot be parsed |
| `ErrorExpired` | `action_token: expired` | Older than 5 minutes |
| `ErrorInvalidField` | `action_token: invalid_purpose` | Issued for a different action type |
| `ErrorMissingField` | `action_token: missing` | Not provided |
| `ErrorInvalidStatus` | `card_status: not_active` | Card is not `Active` |

### Example: Retrieve Details with a Wallet Signature

```javascript
const API_BASE = 'https://api-baas.wirexapp.com';

async function getCardDetails(accessToken, cardId, eoa, chainId, wallet) {
  const headers = {
    Authorization: `Bearer ${accessToken}`,
    'X-User-Wallet': eoa,
    'X-Chain-Id': String(chainId),
    'Content-Type': 'application/json',
  };

  const nonce = Math.floor(Date.now() / 1000);
  const message = `By signing this I confirm that I am executing action GetCardDetails at ${nonce}`;
  const message_signature = await wallet.signMessage(message);

  const verify = await fetch(`${API_BASE}/api/v1/confirmation/signature/verify`, {
    method: 'POST',
    headers,
    body: JSON.stringify({ action_type: 'GetCardDetails', message_signature, nonce }),
  });
  const { action_token } = await verify.json();

  const post = async (path) => {
    const res = await fetch(`${API_BASE}/api/v1/cards/${cardId}/${path}`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ action_token }),
    });
    return res.json();
  };

  const { card_number, expiry_date } = await post('details');
  const { cvv } = await post('cvv');
  return { card_number, expiry_date, cvv };
}
```

SMS variant: `POST /api/v1/confirmation/sms` -> collect the code from the user -> `POST /api/v1/confirmation/sms/verify` -> use the returned `token` as `action_token`.

---

## Card Limits

Four limits: daily, monthly, per-transaction (settable) and lifetime (read-only). A positive number is a hard cap, `-1` means no limit, `0` blocks all spending. Resets are at fixed UTC boundaries: daily at 00:00 UTC, monthly at 00:00 UTC on the 1st; lifetime never resets; per-transaction has no usage counter. A new card starts with all limits at `-1`.

### Get Current Limits

```
GET /api/v1/cards/{cardId}
```

```json
{
  "limit": {
    "daily_limit": 1000.00,
    "daily_usage": 250.00,
    "monthly_limit": -1,
    "monthly_usage": 500.00,
    "lifetime_limit": -1,
    "lifetime_usage": 1500.00,
    "currency": "EUR"
  }
}
```

`transaction_limit` is not in this response; it is in the `card-limits` webhook.

### Set Limits

```
PUT /api/v1/cards/{cardId}/limit
```

```json
{ "daily_limit": 1000.00, "monthly_limit": 20000.00, "transaction_limit": 500.00 }
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `daily_limit` | number | No | Per calendar day; `-1` disables |
| `monthly_limit` | number | No | Per calendar month; `-1` disables |
| `transaction_limit` | number | No | Per single transaction; `-1` disables |
| `limit` | number | No | Obsolete alias of `daily_limit` |

Send only the fields to change (omitted keep their value). `lifetime_limit` is accepted (`200`) but ignored. Response: `200`, empty. To remove one limit: `{ "daily_limit": -1 }`.

Errors: `ErrorInvalidStatus` (`card_status: not_active`), `ErrorNotFound` (card not found or not owned), `ErrorInvalidField` (`card_id: invalid_uuid`), `ErrorMissingField` (`card_id`).

### Limit Webhook

`POST {your_webhook_base_url}/v2/webhooks/card-limits`

```json
{
  "card_id": "64120850-73a1-4df5-a074-d463258c9deb",
  "transaction_limit": -1,
  "daily_limit": 1000.00,
  "daily_usage": 250.00,
  "monthly_limit": -1,
  "monthly_usage": 500.00,
  "lifetime_limit": -1,
  "lifetime_usage": 1500.00
}
```

### Limit Increase for Customers

Standard limits: 30,000 EUR per transaction and 30,000 EUR monthly. Higher limits require valid KYC (PoI/PoA) plus a Support Portal ticket with requested amount, duration (one-off or ongoing), reason, Source of Wealth, and Source of Funds (SoF required for one-off). Outcomes: approved in full, alternative offered, or denied.

---

## Card Top-Up

Funds a wallet from an external Visa/Mastercard (AFT), Apple Pay or Google Pay. `external_card` needs capability `CardTopup`; `apple_pay`/`google_pay` need `WalletTopup`.

### Register Source Card (PCI environment)

User-scoped token required (S2S not supported); `user_id` is the user UUID. PCI base URLs: sandbox `https://wx-acquiring-card-manager-uat.wirexapp.com`, production `https://wx-acquiring-card-manager.wirexapp.com`.

```
POST {pci_base_url}/b2b/cards/topup?user_id={user_id}
GET {pci_base_url}/b2b/cards/topup?user_id={user_id}
DELETE {pci_base_url}/b2b/cards/topup/{card_id}?user_id={user_id}
```

Register body: `{ "card": { "name", "expiry_month", "expiry_year", "number", "cvv", "billing_details": { "address_line1", "address_line2"?, "postal_code", "country", "city", "state"? }, "label" } }` -> `{ "card_id", "card_label" }`. Only Visa and Mastercard; error code `0243` = card already linked to another Wirex account. In browsers use `@wirexapp/card-topup-web` (docs `retail-pci-sdk-topup-collect`) so PAN/CVV never enter your page.

### Estimate

```
POST /api/v1/cards/topup/estimate
```

```json
{
  "external_card_id": "c34908da-d980-4a9c-9b39-4dabd6f6144e",
  "destination_amount": "100000000",
  "destination_token_address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  "payment_method": "external_card"
}
```

`external_card_id` is required for `external_card` (default) and rejected for `apple_pay`/`google_pay`. `destination_amount` is an integer string in token base units. Response: `estimation_id`, `expires_at` (Unix seconds), `source_amount`, `source_amount_precise`, `source_currency`, `destination_amount`, `destination_amount_precise`, `destination_token_address`, `destination_token_symbol`, `fee_amount`, `fee_amount_precise`, `fee_currency`, `rate`, `provider`.

### Execute

```
POST /api/v1/cards/topup/execute
```

Body: `estimation_id` (required), `device_id` (optional). For a wallet-method estimation also `wallet_payment_token` (max 16384 chars), `cardholder_name`, `billing_address` (`country_code`, `city`, `postal_code`, `address_line1` required; `state`, `address_line2` optional) and optional `wallet_transaction_id` (max 128); these are rejected for an `external_card` estimation. Response: `id`, `status`, optional `three_ds_state` (`flow` `frictionless`|`challenge`, `provider`, `status`, `status_reason`, `url`). For `challenge`, open `url`; for `frictionless` no action.

Completion webhook: `POST /v2/webhooks/activities` with `type: CardTopup`, `direction: Inbound`, `source.type: ExternalCard`, steps `Initiated`, `CardIn`, `Review`, `CryptoIn` (`Reversal` if reversed). Errors: `ErrorNotFound` `estimation_id` (not found or expired), `ErrorInvalidField` `payment_method`, plus field-level `ErrorMissingField`/`ErrorInvalidField`.

---

## 3DS Authentication

### Webhook

`POST {your_webhook_base_url}/v2/webhooks/3ds`

```json
{
  "card_id": "64120850-73a1-4df5-a074-d463258c9deb",
  "owner": "0x1234...5678",
  "user_address": "0x1234...5678",
  "transaction_id": "00000000000000000000000000000001",
  "merchant_name": "Amazon",
  "amount": "100.00",
  "currency": "USD",
  "card_last_4": "1234"
}
```

`owner` is deprecated and mirrors `user_address`. `transaction_id` is used for approve/decline. The payload carries no expiry; a request expires 5 minutes after creation.

### Get Pending 3DS Requests

```
GET /api/v1/cards/3ds/requests
```

Response: JSON array (no `data` envelope; empty array when nothing is pending) of the webhook-shaped objects. Scoped to the caller; only undecided, unexpired requests.

### Approve / Decline

```
POST /api/v1/cards/3ds/requests/{transactionId}/approve
POST /api/v1/cards/3ds/requests/{transactionId}/decline
```

No request body, no `action_token`; only the standard auth headers. Response `200 {}`.

| Status | Error Reason | Description |
|--------|--------------|-------------|
| `400` | `ErrorMissingField` | `transaction_id` empty in path |
| `400` | `ErrorNotFound` ("No active 3DS request for this transaction") | Unknown, already decided, expired, or another user's; indistinguishable, terminal, not retryable. No `401` |
| `500` | `ErrorGeneral` | `Failed to query active 3DS requests` / `Failed to approve 3DS request` / `Failed to decline 3DS request` |

A decided request leaves the pending list, so a second decision returns the same `ErrorNotFound`; an approve cannot replay over a decline.

### 3DS Handling Example

```javascript
const API_BASE = 'https://api-baas.wirexapp.com';

// POST /v2/webhooks/3ds handler
async function handle3dsWebhook(payload, headers) {
  const { transaction_id, merchant_name, amount, currency, card_last_4 } = payload;
  const approved = await askUser({ merchant_name, amount, currency, card_last_4 }); // your UI, within 5 minutes
  const action = approved ? 'approve' : 'decline';
  const res = await fetch(`${API_BASE}/api/v1/cards/3ds/requests/${transaction_id}/${action}`, {
    method: 'POST',
    headers,
  });
  if (res.status === 400) return; // no longer active: terminal
}

// Fallback if the webhook was missed
async function listPending3ds(headers) {
  const res = await fetch(`${API_BASE}/api/v1/cards/3ds/requests`, { headers });
  return res.json(); // array
}
```

The OTP-by-SMS method needs no partner calls.

---

## Webhook Payloads

- Card status `POST /v2/webhooks/cards`: same structure as a `GET /api/v1/cards` item (`id`, `card_wallet_address`, `status`, `status_reason`, `previous_status`, `generation`, `provider`, `limit`, `allowed_actions`, `card_data`, `created_at`, `updated_at`; plus `correlation_id`, `chain_id`, precise limit fields, and `funding_token`/`issuer_spender_address` on Bridge cards).
- Card limits `POST /v2/webhooks/card-limits`: see [Limit Webhook](#limit-webhook).
- Activities `POST /v2/webhooks/activities`: `type: CardTransaction` (`direction` `Outbound` debit / `Inbound` credit; `status` `Pending`/`Completed`/`Failed`; `status_reason` e.g. `InsufficientFunds`, `DailySpendAmountIsExceeded`, `GeneralError`; `source_amount`/`destination_amount` are always positive; `operations[].operation_amount` is negative for debits and positive for credits; `activity_steps[]`). Debit steps `Initiated`, `CryptoOut`, `CardOut`, `Completed`, `Reversal`; credit steps `Initiated`, `CardIn`, `CryptoIn`, `Completed`. Crypto amounts may be `0` or missing until the crypto step executes.
- 3DS `POST /v2/webhooks/3ds`: see above.

See [wirex-baas-webhooks reference](../../wirex-baas-webhooks/references/REFERENCE.md) for complete payloads.

---

## Error Codes

Error format:

```json
{
  "error_reason": "ErrorInvalidField",
  "error_description": "Human-readable message",
  "error_category": { "category": "CategoryValidationFailure", "http_status_code": 400 },
  "error_details": [ { "key": "field", "details": "field_name" } ]
}
```

| HTTP | `error_reason` | When |
|------|----------------|------|
| 400 | `ErrorMissingField` | Required field absent (`delivery_address`, `action_token`, `nonce`, ...) |
| 400 | `ErrorInvalidField` | Bad format (e.g. `card_number_last4` not `^\d{4}$`), bad `action_token`/signature/`session_id` |
| 400 | `ErrorInvalidStatus` | Action not allowed in the card's current status |
| 400 | `ErrorNotSupported` | e.g. PIN on a non-physical card |
| 400 | `ErrorNotFound` | No delivery methods/fees for country; no active 3DS request; card not found |
| 400 | `ErrorGeneral` | `Delivery ID is required and must be positive`; `Card fees are not enforced`; invalid `payment_system` |
| 400 | `ErrorExpired` | Expired `action_token` |
| 500 | `ErrorGeneral` | `Failed to issue virtual card` / `Failed to issue plastic card` / `Failed to activate card` / `Failed to get card` / `Failed to process delivery payment` |
| 500 | `ErrorGeneral` | `Virtual card capability is not active` (`CategoryInternalFailure`) -- a precondition failure, not transient; check capabilities before issuing |

---

## Field Validation Patterns

| Field | Validation |
|-------|-----------|
| `card_name` / change-name `name` | `^[a-zA-Z0-9\-':+# @]{1,50}$` |
| `name_on_card` | Published rule `^[A-Za-z][A-Za-z .'-]{1,25}$` (2-26 chars, starts with a letter); not enforced by the API per the validation-rules guide, the card processor may still reject (`400 "Request failed due to external validation failure"`) |
| `card_number_last4` | Exactly 4 digits |
| `expiry_date` (activation) | `MM/YYYY` |
| `delivery_address.*` | See [Address Fields](#address-fields) |
| `{type}` (fees/invoice) | `virtual`, `plastic`, `metal` (case-insensitive) |
| `payment_system` (v3) | `Visa` or `MasterCard` |
| `limit` values | Number; `-1` disables, `0` blocks all spending |
| `action_token` | Valid 5 minutes, single use |
| `nonce` | Unix seconds, valid 5 minutes |
| `session_id` | UUID |
