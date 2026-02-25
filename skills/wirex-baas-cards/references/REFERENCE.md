# Card API Reference

Complete API reference for all Wirex BaaS card management endpoints.

---

## Table of Contents

- [Required Headers](#required-headers)
- [Card Listing and Details](#card-listing-and-details)
- [Card Issuance -- Virtual](#card-issuance--virtual)
- [Card Issuance -- Physical](#card-issuance--physical)
- [Delivery Options](#delivery-options)
- [Card Lifecycle Management](#card-lifecycle-management)
- [Verification and Confirmation](#verification-and-confirmation)
- [Secure Card Details Retrieval](#secure-card-details-retrieval)
- [Card Limits](#card-limits)
- [Card Withdrawal and Transfer](#card-withdrawal-and-transfer)
- [3DS Authentication](#3ds-authentication)
- [Webhook Payloads](#webhook-payloads)
- [Error Codes](#error-codes)
- [Field Validation Patterns](#field-validation-patterns)

---

## Required Headers

All card API endpoints require the following headers:

| Header | Required | Description |
|--------|----------|-------------|
| `Authorization` | Yes | Bearer token for authentication |
| `X-User-Address` | Yes | User's EOA (Externally Owned Account) address. Must be the EOA address, not the Smart Wallet address |
| `X-Chain-Id` | Yes | Blockchain chain ID |

**Example:**

```
Authorization: Bearer {user_token}
X-User-Address: 0x1234...abcd
X-Chain-Id: 8453
```

---

## Card Listing and Details

### List All Cards

```
GET /api/v1/cards
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `status` | string | No | Filter by status: `Active`, `Blocked`, `Closed`, `Requested`, `NotActivated` |
| `card_type` | string | No | Filter by type: `Virtual`, `Plastic`, `Metal` |
| `limit` | integer | No | Max results per page (default: 20, max: 100) |
| `offset` | integer | No | Pagination offset (default: 0) |

**Response: `200 OK`**

```json
{
  "cards": [
    {
      "card_id": "card_virt_001",
      "card_type": "Virtual",
      "status": "Active",
      "currency": "USD",
      "last_four": "4321",
      "expiry_month": 12,
      "expiry_year": 2028,
      "created_at": "2025-03-15T10:00:00Z",
      "limits": {
        "daily": { "amount": 5000, "currency": "USD", "used": 250 },
        "monthly": { "amount": 25000, "currency": "USD", "used": 1200 },
        "lifetime": { "amount": -1, "currency": "USD", "used": 15000 }
      }
    },
    {
      "card_id": "card_phys_002",
      "card_type": "Plastic",
      "status": "NotActivated",
      "currency": "USD",
      "last_four": "8765",
      "expiry_month": 6,
      "expiry_year": 2029,
      "created_at": "2025-03-10T14:00:00Z",
      "delivery_method": "standard",
      "estimated_delivery": "2025-03-24",
      "limits": {
        "daily": { "amount": 5000, "currency": "USD", "used": 0 },
        "monthly": { "amount": 25000, "currency": "USD", "used": 0 },
        "lifetime": { "amount": -1, "currency": "USD", "used": 0 }
      }
    }
  ],
  "total": 2,
  "limit": 20,
  "offset": 0
}
```

---

### Get Single Card

```
GET /api/v1/cards/{cardId}
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `cardId` | string | Yes | Unique card identifier |

**Response: `200 OK`**

```json
{
  "card_id": "card_virt_001",
  "card_type": "Virtual",
  "status": "Active",
  "currency": "USD",
  "last_four": "4321",
  "expiry_month": 12,
  "expiry_year": 2028,
  "cardholder_name": "JANE DOE",
  "created_at": "2025-03-15T10:00:00Z",
  "activated_at": "2025-03-15T10:00:00Z",
  "limits": {
    "daily": {
      "amount": 5000,
      "currency": "USD",
      "used": 250,
      "remaining": 4750,
      "resets_at": "2025-03-16T00:00:00Z"
    },
    "monthly": {
      "amount": 25000,
      "currency": "USD",
      "used": 1200,
      "remaining": 23800,
      "resets_at": "2025-04-01T00:00:00Z"
    },
    "lifetime": {
      "amount": -1,
      "currency": "USD",
      "used": 15000,
      "remaining": null
    }
  },
  "recent_transactions": [
    {
      "transaction_id": "txn_001",
      "amount": "49.99",
      "currency": "USD",
      "merchant_name": "Example Store",
      "stage": "Completed",
      "direction": "debit",
      "timestamp": "2025-03-14T16:30:00Z"
    }
  ]
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `404` | `ErrorNotFound` | Card with the specified ID does not exist |
| `403` | `ErrorPermissionDenied` | Card does not belong to the authenticated user |

---

## Card Issuance -- Virtual

### Get Virtual Card Fees

```
GET /api/v1/cards/Virtual/fees/{country}
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

> **Note:** This method is applicable only if your account manager has advised you to incorporate card fee handling.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Response: `200 OK`**

```json
{
  "card_type": "Virtual",
  "country": "GB",
  "currency": "USD",
  "fee_amount": "1.00",
  "fee_description": "Virtual card issuance fee",
  "fee_breakdown": [
    {
      "type": "issuance",
      "amount": "1.00",
      "currency": "USD"
    }
  ]
}
```

---

### Pay Virtual Card Fee (Create Invoice)

```
POST /api/v2/cards/Virtual/fees/{country}/payment
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

> **Note:** This method is applicable only if your account manager has advised you to incorporate card fee handling.

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `token_address` | string | Yes | Token contract address for fee payment |

**Request Example:**

```json
{
  "token_address": "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
}
```

**Response: `201 Created`**

```json
{
  "delivery_id": 12345,
  "card_type": "Virtual",
  "amount": "1.00",
  "currency": "USD",
  "status": "paid",
  "created_at": "2025-03-15T09:55:00Z",
  "expires_at": "2025-03-15T10:55:00Z"
}
```

> **Note:** The `expires_at` indicates how long the invoice is valid for card issuance. Use the `delivery_id` in the card creation request before it expires.

---

### Issue Virtual Card

```
POST /api/v2/cards/virtual
Content-Type: application/json
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `currency` | string | Yes | Card currency (ISO 4217): `USD`, `EUR`, `GBP` |
| `delivery_id` | integer | Yes | Delivery ID from the fee payment step |
| `card_name` | string | No | Friendly name for the card (e.g., "My Shopping Card") |
| `name_on_card` | string | No | Name printed on the card |

**Request Example:**

```json
{
  "currency": "USD",
  "delivery_id": 12345,
  "card_name": "My Virtual Card",
  "name_on_card": "JANE DOE"
}
```

**Response: `201 Created`**

```json
{
  "card_id": "card_virt_001",
  "card_type": "Virtual",
  "status": "Active",
  "currency": "USD",
  "last_four": "4321",
  "expiry_month": 12,
  "expiry_year": 2028,
  "cardholder_name": "JANE DOE",
  "created_at": "2025-03-15T10:00:00Z",
  "activated_at": "2025-03-15T10:00:00Z",
  "limits": {
    "daily": { "amount": 5000, "currency": "USD", "used": 0 },
    "monthly": { "amount": 25000, "currency": "USD", "used": 0 },
    "lifetime": { "amount": -1, "currency": "USD", "used": 0 }
  }
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Currency is not supported for virtual cards |
| `400` | `ErrorInvalidField` | Delivery ID is invalid, expired, or already used |
| `403` | `ErrorPermissionDenied` | `VisaVirtualCard` capability is not Active |
| `409` | `ErrorNotSupported` | User has reached the maximum number of virtual cards |
| `422` | `ErrorInvalidField` | User verification status is not Approved |

---

## Card Issuance -- Physical

### Get Physical Card Fees

```
GET /api/v1/cards/Plastic/fees/{country}
Authorization: Bearer {user_token}
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Response: `200 OK`**

```json
{
  "card_type": "Plastic",
  "country": "GB",
  "currency": "USD",
  "fee_amount": "10.00",
  "fee_description": "Physical card issuance and standard delivery",
  "fee_breakdown": [
    {
      "type": "issuance",
      "amount": "5.00",
      "currency": "USD"
    },
    {
      "type": "delivery_standard",
      "amount": "5.00",
      "currency": "USD"
    }
  ]
}
```

---

### Pay Physical Card Fee (Create Invoice)

```
POST /api/v2/cards/Plastic/fees/{country}/payment
Authorization: Bearer {user_token}
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Request Body (optional):**

```json
{
  "delivery_method": "express"
}
```

**Response: `201 Created`**

```json
{
  "invoice_id": "inv_def456",
  "card_type": "Plastic",
  "amount": "20.00",
  "currency": "USD",
  "status": "paid",
  "created_at": "2025-03-15T09:55:00Z",
  "expires_at": "2025-03-15T10:55:00Z"
}
```

---

### Issue Physical Card

```
POST /api/v2/cards/plastic
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `currency` | string | Yes | Card currency (ISO 4217) |
| `invoice_id` | string | Yes | Invoice ID from fee payment |
| `delivery_method` | string | Yes | `standard` or `express` |
| `delivery_address` | object | Yes | Shipping address |
| `delivery_address.line1` | string | Yes | Street address line 1 |
| `delivery_address.line2` | string | No | Street address line 2 |
| `delivery_address.city` | string | Yes | City |
| `delivery_address.state` | string | No | State or province |
| `delivery_address.post_code` | string | Yes | Postal / ZIP code |
| `delivery_address.country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Request Example:**

```json
{
  "currency": "USD",
  "invoice_id": "inv_def456",
  "delivery_method": "standard",
  "delivery_address": {
    "line1": "10 Downing Street",
    "line2": "",
    "city": "London",
    "state": "England",
    "post_code": "SW1A 2AA",
    "country": "GB"
  }
}
```

**Response: `201 Created`**

```json
{
  "card_id": "card_phys_002",
  "card_type": "Plastic",
  "status": "Requested",
  "currency": "USD",
  "last_four": "8765",
  "expiry_month": 6,
  "expiry_year": 2029,
  "cardholder_name": "JANE DOE",
  "delivery_method": "standard",
  "estimated_delivery": "2025-03-29",
  "delivery_address": {
    "line1": "10 Downing Street",
    "line2": "",
    "city": "London",
    "state": "England",
    "post_code": "SW1A 2AA",
    "country": "GB"
  },
  "created_at": "2025-03-15T10:00:00Z"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Currency is not supported for physical cards |
| `400` | `ErrorInvalidField` | Invoice ID is invalid, expired, or already used |
| `400` | `ErrorInvalidField` | One or more address fields are invalid |
| `400` | `ErrorInvalidField` | Delivery method is not available for this country |
| `403` | `ErrorPermissionDenied` | `VisaPlasticCard` capability is not Active |
| `409` | `ErrorNotSupported` | User has reached the maximum number of physical cards |
| `422` | `ErrorInvalidField` | Delivery is not available to this country |
| `422` | `ErrorInvalidField` | User verification status is not Approved |

---

## Delivery Options

### Get Delivery Countries

```
GET /api/v1/cards/delivery/countries
Authorization: Bearer {user_token}
```

**Response: `200 OK`**

```json
{
  "countries": [
    {
      "country_code": "GB",
      "country_name": "United Kingdom",
      "methods_available": ["standard", "express"]
    },
    {
      "country_code": "DE",
      "country_name": "Germany",
      "methods_available": ["standard"]
    },
    {
      "country_code": "US",
      "country_name": "United States",
      "methods_available": ["standard", "express"]
    }
  ]
}
```

---

### Get Delivery Methods for Country

```
GET /api/v1/cards/delivery/methods/{country}
Authorization: Bearer {user_token}
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `country` | string | Yes | ISO 3166-1 alpha-2 country code |

**Response: `200 OK`**

```json
{
  "country": "GB",
  "methods": [
    {
      "method": "standard",
      "estimated_days": "7-14",
      "fee": "0.00",
      "fee_currency": "USD",
      "tracking_available": false
    },
    {
      "method": "express",
      "estimated_days": "2-5",
      "fee": "15.00",
      "fee_currency": "USD",
      "tracking_available": true
    }
  ]
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `404` | `ErrorNotFound` | Country code is not recognized |
| `422` | `ErrorNotSupported` | Card delivery is not available to this country |

---

## Card Lifecycle Management

### Activate Card (Physical Only)

```
PUT /api/v1/cards/{cardId}/activate
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `last_four` | string | Yes | Last four digits of the card number (printed on the physical card) |

**Request Example:**

```json
{
  "last_four": "8765"
}
```

**Response: `200 OK`**

```json
{
  "card_id": "card_phys_002",
  "status": "Active",
  "activated_at": "2025-03-25T14:00:00Z"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Last four digits do not match the card |
| `400` | `ErrorInvalidStatus` | Card is already activated |
| `400` | `ErrorNotSupported` | Virtual cards are auto-activated; this endpoint is for physical cards only |
| `404` | `ErrorNotFound` | Card not found |
| `400` | `ErrorInvalidStatus` | Card status is still `Requested` (not yet delivered) |

---

### Block Card

```
PUT /api/v1/cards/{cardId}/block
Authorization: Bearer {user_token}
```

**Request Body (optional):**

```json
{
  "reason": "lost"
}
```

| Reason | Description |
|--------|-------------|
| `lost` | Card is lost |
| `stolen` | Card is stolen |
| `suspicious_activity` | Suspected fraudulent activity |
| `user_request` | General user request (default) |

**Response: `200 OK`**

```json
{
  "card_id": "card_virt_001",
  "status": "Blocked",
  "blocked_at": "2025-03-15T12:00:00Z",
  "reason": "lost"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidStatus` | Card is already blocked |
| `400` | `ErrorInvalidStatus` | Cannot block a closed card |
| `404` | `ErrorNotFound` | Card not found |

---

### Unblock Card

```
PUT /api/v1/cards/{cardId}/unblock
Authorization: Bearer {user_token}
```

**Response: `200 OK`**

```json
{
  "card_id": "card_virt_001",
  "status": "Active",
  "unblocked_at": "2025-03-15T13:00:00Z"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidStatus` | Card is not in Blocked status |
| `400` | `ErrorInvalidStatus` | Cannot unblock a closed card |
| `403` | `ErrorPermissionDenied` | Card was blocked for `stolen`; cannot be unblocked (must be closed) |
| `404` | `ErrorNotFound` | Card not found |

---

### Close Card

```
PUT /api/v1/cards/{cardId}/close
Authorization: Bearer {user_token}
```

**Request Body (optional):**

```json
{
  "reason": "no_longer_needed"
}
```

**Response: `200 OK`**

```json
{
  "card_id": "card_virt_001",
  "status": "Closed",
  "closed_at": "2025-03-15T14:00:00Z",
  "reason": "no_longer_needed"
}
```

> **Warning:** Closing a card is **irreversible**. The card cannot be reactivated. Any pending transactions will be declined.

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidStatus` | Card is already closed |
| `400` | `ErrorNotSupported` | Card has pending transactions; wait for settlement or force-close |
| `404` | `ErrorNotFound` | Card not found |

---

## Verification and Confirmation

Before retrieving sensitive card details (PAN, CVV, PIN), a verification step is required to generate an `action_token`.

### Signature Verification

```
POST /api/v1/confirmation/signature/verify
Content-Type: application/json
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action_type` | string | Yes | Enum: `GetCardDetails`, `3dsChallenge`, `VerifyPhone` |
| `message_signature` | string | Yes | EIP-191 or EIP-712 signed message from the user's EOA |
| `nonce` | number | Yes | Unix timestamp (seconds) |

**Request Example:**

```json
{
  "action_type": "GetCardDetails",
  "message_signature": "0x1234abcd...signed_message_hex",
  "nonce": 1710496200
}
```

**Response: `200 OK`**

```json
{
  "token": "action-token-string"
}
```

> **Note:** The `token` (action_token) expires in **5 minutes** and is single-use per detail type.

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Signature does not match the user's registered EOA |
| `400` | `ErrorInvalidField` | Invalid action_type or nonce |
| `401` | `ErrorPermissionDenied` | Invalid or expired user token |

---

### Request SMS OTP

```
POST /api/v1/confirmation/sms
Content-Type: application/json
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action_type` | string | Yes | Enum: `GetCardDetails`, `3dsChallenge`, `VerifyPhone` |

**Request Example:**

```json
{
  "action_type": "GetCardDetails"
}
```

**Response: `200 OK`**

```json
{
  "session_id": "uuid-session-id",
  "code_length": 6,
  "expires_at": "2025-03-15T10:05:00Z"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | User's phone number is not confirmed |
| `400` | `ErrorInvalidField` | Invalid action_type value |
| `429` | `ErrorInvalidField` | Too many SMS requests; retry after cooldown |

---

### Verify SMS OTP

```
POST /api/v1/confirmation/sms/verify
Content-Type: application/json
Authorization: Bearer {user_token}
X-User-Address: {eoa_address}
X-Chain-Id: {chain_id}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `session_id` | string | Yes | Session ID returned from the SMS request |
| `code` | string | Yes | 6-digit SMS verification code |

**Request Example:**

```json
{
  "session_id": "uuid-session-id",
  "code": "123456"
}
```

**Response: `200 OK`**

```json
{
  "token": "action-token-string"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Verification code is incorrect |
| `400` | `ErrorInvalidField` | Session ID is not recognized |
| `410` | `ErrorExpired` | Verification code has expired (5-minute validity) |
| `429` | `ErrorInvalidField` | Too many failed attempts; request a new code |

---

## Secure Card Details Retrieval

All card detail endpoints require a valid `action_token` from the verification step. The token expires after **5 minutes** and is single-use per detail type.

### Get PAN (Full Card Number)

```
POST /api/v1/cards/{cardId}/details
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action_token` | string | Yes | Token from signature or SMS verification |

**Request Example:**

```json
{
  "action_token": "act_token_abc123"
}
```

**Response: `200 OK`**

```json
{
  "pan": "4111111111114321",
  "expiry_month": 12,
  "expiry_year": 2028,
  "cardholder_name": "JANE DOE"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Action token is invalid |
| `401` | `ErrorExpired` | Action token has expired (5-minute window) |
| `403` | `ErrorPermissionDenied` | Card must be in Active status to retrieve details |
| `404` | `ErrorNotFound` | Card not found |

---

### Get CVV

```
POST /api/v1/cards/{cardId}/cvv
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

```json
{
  "action_token": "act_token_abc123"
}
```

**Response: `200 OK`**

```json
{
  "cvv": "123"
}
```

**Error Responses:** Same as PAN retrieval.

---

### Get PIN

```
POST /api/v1/cards/{cardId}/pin
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

```json
{
  "action_token": "act_token_abc123"
}
```

**Response: `200 OK`**

```json
{
  "pin": "1234"
}
```

**Error Responses:** Same as PAN retrieval.

---

### Complete Card Details Retrieval Example

```javascript
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';

async function getCardDetailsWithSignature(userToken, cardId, eoa, chainId, messageSignature, nonce) {
  const headers = {
    Authorization: `Bearer ${userToken}`,
    'X-User-Address': eoa,
    'X-Chain-Id': chainId.toString(),
  };

  // Step 1: Verify signature to get action_token
  const verifyResponse = await axios.post(
    `${API_BASE}/api/v1/confirmation/signature/verify`,
    { action_type: 'GetCardDetails', message_signature: messageSignature, nonce },
    { headers }
  );

  const actionToken = verifyResponse.data.token;

  // Step 2: Retrieve PAN
  const panResponse = await axios.post(
    `${API_BASE}/api/v1/cards/${cardId}/details`,
    { action_token: actionToken },
    { headers }
  );

  // Step 3: Retrieve CVV (need a new action_token — single-use per detail type)
  const cvvResponse = await axios.post(
    `${API_BASE}/api/v1/cards/${cardId}/cvv`,
    { action_token: actionToken },
    { headers }
  );

  // Step 4: Retrieve PIN (physical cards only)
  const pinResponse = await axios.post(
    `${API_BASE}/api/v1/cards/${cardId}/pin`,
    { action_token: actionToken },
    { headers }
  );

  return {
    pan: panResponse.data.pan,
    expiry_month: panResponse.data.expiry_month,
    expiry_year: panResponse.data.expiry_year,
    cardholder_name: panResponse.data.cardholder_name,
    cvv: cvvResponse.data.cvv,
    pin: pinResponse.data.pin,
  };
}

async function getCardDetailsWithSms(userToken, cardId, eoa, chainId) {
  const headers = {
    Authorization: `Bearer ${userToken}`,
    'X-User-Address': eoa,
    'X-Chain-Id': chainId.toString(),
  };

  // Step 1: Request SMS OTP
  const smsResponse = await axios.post(
    `${API_BASE}/api/v1/confirmation/sms`,
    { action_type: 'GetCardDetails' },
    { headers }
  );

  const { session_id } = smsResponse.data;

  // Step 2: Wait for user to enter SMS code (from UI)
  const smsCode = await promptUserForSmsCode(); // your UI implementation

  // Step 3: Verify SMS code
  const verifyResponse = await axios.post(
    `${API_BASE}/api/v1/confirmation/sms/verify`,
    { session_id, code: smsCode },
    { headers }
  );

  const actionToken = verifyResponse.data.token;

  // Step 4: Retrieve details (same as signature flow)
  const panResponse = await axios.post(
    `${API_BASE}/api/v1/cards/${cardId}/details`,
    { action_token: actionToken },
    { headers }
  );

  return panResponse.data;
}
```

---

## Card Limits

### Update Card Limits

```
PUT /api/v1/cards/{cardId}/limit
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body:**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `daily` | number | No | Daily spending limit in card currency. `-1` = no limit, `0` = fully restricted |
| `monthly` | number | No | Monthly spending limit. `-1` = no limit, `0` = fully restricted |
| `lifetime` | number | No | Lifetime spending limit. `-1` = no limit, `0` = fully restricted |

**Request Example:**

```json
{
  "daily": 10000,
  "monthly": 50000,
  "lifetime": -1
}
```

**Response: `200 OK`**

```json
{
  "card_id": "card_virt_001",
  "limits": {
    "daily": {
      "amount": 10000,
      "currency": "USD",
      "used": 250,
      "remaining": 9750,
      "resets_at": "2025-03-16T00:00:00Z"
    },
    "monthly": {
      "amount": 50000,
      "currency": "USD",
      "used": 1200,
      "remaining": 48800,
      "resets_at": "2025-04-01T00:00:00Z"
    },
    "lifetime": {
      "amount": -1,
      "currency": "USD",
      "used": 15000,
      "remaining": null
    }
  },
  "updated_at": "2025-03-15T11:00:00Z"
}
```

**Limit Value Reference:**

| Value | Meaning | Example |
|-------|---------|---------|
| `5000` | $5,000 limit | Standard daily limit |
| `0` | Fully restricted | No transactions allowed |
| `-1` | Unlimited | No cap on spending |

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorInvalidField` | Limit value must be -1 or a non-negative number |
| `400` | `ErrorInvalidField` | Cannot set limit below the already-used amount in current period |
| `400` | `ErrorInvalidField` | Daily limit cannot exceed monthly limit |
| `400` | `ErrorInvalidField` | Monthly limit cannot exceed lifetime limit (when both are positive) |
| `403` | `ErrorPermissionDenied` | Limits can only be changed on Active cards |
| `404` | `ErrorNotFound` | Card not found |

---

## 3DS Authentication

### Get Pending 3DS Requests

```
GET /api/v1/cards/3ds/requests
Authorization: Bearer {user_token}
```

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `card_id` | string | No | Filter by specific card |
| `status` | string | No | Filter: `pending`, `approved`, `declined`, `expired` |

**Response: `200 OK`**

```json
{
  "requests": [
    {
      "request_id": "3ds_req_001",
      "card_id": "card_virt_001",
      "card_last_four": "4321",
      "merchant_name": "Example Store",
      "merchant_country": "GB",
      "merchant_category_code": "5411",
      "amount": "49.99",
      "currency": "USD",
      "status": "pending",
      "created_at": "2025-03-15T10:30:00Z",
      "expires_at": "2025-03-15T10:35:00Z"
    }
  ],
  "total": 1
}
```

---

### Approve 3DS Request

```
POST /api/v1/cards/3ds/requests/{requestId}/approve
Authorization: Bearer {user_token}
```

**Path Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `requestId` | string | Yes | The 3DS request identifier |

**Response: `200 OK`**

```json
{
  "request_id": "3ds_req_001",
  "status": "approved",
  "approved_at": "2025-03-15T10:31:00Z"
}
```

**Error Responses:**

| Status | Error Reason | Description |
|--------|-------------|-------------|
| `400` | `ErrorNotSupported` | Request has already been approved or declined |
| `404` | `ErrorNotFound` | 3DS request not found |
| `410` | `ErrorExpired` | 3DS request has expired |

---

### Decline 3DS Request

```
POST /api/v1/cards/3ds/requests/{requestId}/decline
Content-Type: application/json
Authorization: Bearer {user_token}
```

**Request Body (optional):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `reason` | string | No | Decline reason for logging |

**Request Example:**

```json
{
  "reason": "unrecognized_merchant"
}
```

| Reason Value | Description |
|-------------|-------------|
| `unrecognized_merchant` | User does not recognize the merchant |
| `amount_mismatch` | Transaction amount is unexpected |
| `suspected_fraud` | User suspects fraud |
| `user_declined` | General decline (default) |

**Response: `200 OK`**

```json
{
  "request_id": "3ds_req_001",
  "status": "declined",
  "reason": "unrecognized_merchant",
  "declined_at": "2025-03-15T10:31:30Z"
}
```

**Error Responses:** Same as approve.

---

### 3DS Handling Example

```javascript
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';

// Webhook handler for 3DS requests
async function handle3dsWebhook(webhookPayload, userToken) {
  const { request_id, card_id, merchant_name, amount, currency, expires_at } =
    webhookPayload;

  console.log(
    `3DS request: ${merchant_name} wants to charge ${amount} ${currency}`
  );

  // Check if request is still valid
  if (new Date(expires_at) < new Date()) {
    console.log('3DS request already expired.');
    return;
  }

  // Decision logic (replace with your business rules)
  const shouldApprove = await evaluateTransaction({
    card_id,
    merchant_name,
    amount: parseFloat(amount),
    currency,
  });

  if (shouldApprove) {
    await axios.post(
      `${API_BASE}/api/v1/cards/3ds/requests/${request_id}/approve`,
      {},
      { headers: { Authorization: `Bearer ${userToken}` } }
    );
    console.log(`3DS request ${request_id} approved.`);
  } else {
    await axios.post(
      `${API_BASE}/api/v1/cards/3ds/requests/${request_id}/decline`,
      { reason: 'user_declined' },
      { headers: { Authorization: `Bearer ${userToken}` } }
    );
    console.log(`3DS request ${request_id} declined.`);
  }
}

// Poll for pending 3DS requests (alternative to webhook)
async function checkPending3ds(userToken) {
  const response = await axios.get(
    `${API_BASE}/api/v1/cards/3ds/requests?status=pending`,
    { headers: { Authorization: `Bearer ${userToken}` } }
  );

  return response.data.requests;
}
```

---

## Webhook Payloads

See [wirex-baas-webhooks reference](../wirex-baas-webhooks/references/REFERENCE.md) for complete card-related webhook payloads (card status, card limits, card activity, 3DS).

---

## Error Codes

### General Error Response Format

All errors follow this structure:

```json
{
  "error_reason": "ErrorNotFound",
  "error_description": "Card with ID card_xyz does not exist.",
  "error_category": {
    "category": "CategoryNotFound",
    "http_status_code": 404
  },
  "error_details": [
    { "key": "field", "details": "card_id" }
  ]
}
```

### Complete Error Code Reference

| HTTP Status | Error Reason | Description |
|-------------|-------------|-------------|
| `400` | `ErrorInvalidField` | Request body failed validation, invalid currency, delivery address, last four, action token, signature, SMS code, limit value, or phone not confirmed |
| `400` | `ErrorNotSupported` | Operation not allowed: card already active/blocked/closed, virtual card activation attempt, pending transactions, card closed, card not blocked |
| `400` | `ErrorInvalidField` | Limit constraints violated: limit below used amount, daily exceeds monthly, monthly exceeds lifetime |
| `401` | `ErrorPermissionDenied` | Invalid or expired token or action token |
| `403` | `ErrorPermissionDenied` | Card does not belong to user, capability not active, card not active, unblock not allowed (stolen) |
| `404` | `ErrorNotFound` | Card, country, or 3DS request not found |
| `409` | `ErrorNotSupported` | Maximum card count reached |
| `410` | `ErrorExpired` | SMS code or 3DS request expired |
| `422` | `ErrorInvalidField` | KYC not approved, country not supported, card not delivered, delivery not available |
| `429` | `ErrorInvalidField` | Rate limited or max verification attempts reached |

---

## Field Validation Patterns

### Card Issuance Fields

| Field | Validation | Valid Examples | Invalid Examples |
|-------|-----------|----------------|------------------|
| `currency` | ISO 4217, 3 uppercase letters | `"USD"`, `"EUR"`, `"GBP"` | `"usd"`, `"US"`, `"USDT"` |
| `invoice_id` | Non-empty string, starts with `inv_` | `"inv_abc123"` | `""`, `"abc123"` |
| `delivery_method` | Enum: `standard`, `express` | `"standard"` | `"overnight"`, `"fast"` |

### Address Fields

| Field | Validation | Max Length |
|-------|-----------|-----------|
| `delivery_address.line1` | Required, non-empty | 200 chars |
| `delivery_address.line2` | Optional | 200 chars |
| `delivery_address.city` | Required, non-empty | 100 chars |
| `delivery_address.state` | Optional | 100 chars |
| `delivery_address.post_code` | Required, non-empty | 20 chars |
| `delivery_address.country` | Required, ISO 3166-1 alpha-2 | 2 chars |

### Limit Fields

| Field | Type | Validation |
|-------|------|-----------|
| `daily` | number | Integer, >= -1 |
| `monthly` | number | Integer, >= -1, >= daily (when both positive) |
| `lifetime` | number | Integer, >= -1, >= monthly (when both positive) |

### Action Token

| Field | Validation |
|-------|-----------|
| `action_token` | Non-empty string, starts with `act_`, valid for 5 minutes from issuance |

### SMS Code

| Field | Validation |
|-------|-----------|
| `code` | Exactly 6 digits, numeric only |
| `session_id` | Non-empty UUID string |

### Last Four (Activation)

| Field | Validation |
|-------|-----------|
| `last_four` | Exactly 4 digits, numeric only, must match card |

