# Wirex BaaS Authentication -- Endpoint Reference

Complete endpoint specifications for all authentication-related API calls, including full request/response examples, JWT claims, headers, and error responses.

---

## Endpoints Overview

| Method | Endpoint | Auth Required | User Identity | Description |
|---|---|---|---|---|
| POST | `/api/v1/token` | No | No | S2S OAuth2 token exchange |
| POST | `/api/v1/user/authorize` | S2S Bearer | Yes (`X-User-Address`) | User token issuance |
| POST | `/api/v1/user/retail` | Privy tokens | No | Privy user registration |
| POST | `/api/v1/user` | S2S Bearer | No | Create user (v1) |
| POST | `/api/v2/user` | S2S Bearer | No | Create user (v2) |

---

## POST /api/v1/token

Exchanges partner credentials for an S2S access token using OAuth2 client credentials grant.

### Request

**URL:** `{base_url}/api/v1/token`

**Method:** `POST`

**Headers:**

| Header | Value | Required |
|---|---|---|
| `Content-Type` | `application/json` | Yes |

**Body Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `client_id` | string | Yes | Partner application UUID. Provided during onboarding. |
| `client_secret` | string | Yes | Partner secret string. Must be kept confidential. |
| `grant_type` | string | Yes | Must be exactly `client_credentials`. |

### Success Response (200 OK)

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI5cWdLN3h6UWlybUpnWmk5ek9hbUxYUTZkUTdLcFV1OSIsInNjb3BlIjoicGFydG5lcjpmdWxsIiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAxNzI4MDB9.abc123signature",
  "token_type": "Bearer",
  "expires_at": 1700172800
}
```

**Response Fields:**

| Field | Type | Description |
|---|---|---|
| `access_token` | string | JWT access token. Use as `Bearer {token}` in the Authorization header for subsequent requests. |
| `token_type` | string | Always `Bearer`. |
| `expires_at` | integer | Unix timestamp (seconds since epoch) when the token expires. The token is valid for 48 hours from issuance. |

### Error Responses

**Invalid credentials (401):**

```json
{
  "error_reason": "ErrorPermissionDenied",
  "error_description": "Invalid client credentials",
  "error_category": {
    "category": "CategoryUnauthorized",
    "http_status_code": 401
  },
  "error_details": [
    {"key": "field", "details": "client_secret"}
  ]
}
```

**Missing required field (400):**

```json
{
  "error_reason": "ErrorMissingField",
  "error_description": "The 'grant_type' field is required.",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  }
}
```

---

## POST /api/v1/user/authorize

Issues a user-scoped access token. Requires a valid S2S token and user identification.

### Request

**URL:** `{base_url}/api/v1/user/authorize`

**Method:** `POST`

**Headers:**

| Header | Value | Required |
|---|---|---|
| `Authorization` | `Bearer <s2s_access_token>` | Yes |
| `X-Chain-Id` | Chain ID (e.g., `84532`, `8453`, `9223372036854775806`) | Yes |
| `X-User-Address` | User's EOA address (not Smart Wallet) | Yes |
| `Content-Type` | `application/json` | Yes |

**Body:** Empty object `{}` or omitted.

### Success Response (200 OK)

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIweDEyMzQ1Njc4OTBhYmNkZWYxMjM0NTY3ODkwYWJjZGVmMTIzNDU2NzgiLCJzY29wZSI6InVzZXI6ZnVsbCIsInBhcnRuZXJfaWQiOiIweDAw...IiwiaWF0IjoxNzAwMDAwMDAwLCJleHAiOjE3MDAxNzI4MDB9.xyz789signature",
  "token_type": "Bearer",
  "expires_at": 1700172800
}
```

### Error Responses

**Missing X-Chain-Id (400):**

```json
{
  "error_reason": "ErrorMissingField",
  "error_description": "X-Chain-Id header is required",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  }
}
```

**User not found (400):**

```json
{
  "error_reason": "ErrorNotFound",
  "error_description": "No user found with the provided wallet address",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  }
}
```

**Expired S2S token (401):**

```json
{
  "error_reason": "ErrorExpired",
  "error_description": "Token expired",
  "error_category": {
    "category": "CategoryUnauthorized",
    "http_status_code": 401
  }
}
```

---

## POST /api/v1/user/retail

Registers a new retail user authenticated through Privy.

### Request

**URL:** `{base_url}/api/v1/user/retail`

**Method:** `POST`

**Headers:**

| Header | Value | Required |
|---|---|---|
| `Authorization` | `Bearer <privy_access_token>` (from Privy SDK) | Yes |
| `Identity` | `Bearer <privy_identity_token>` (from Privy SDK) | Yes |
| `X-Chain-Id` | Chain ID | Yes |
| `Content-Type` | `application/json` | Yes |

**Body Parameters:**

| Parameter | Type | Required | Description |
|---|---|---|---|
| `country` | string | Yes | User's country of residence (ISO 3166-1 alpha-2, e.g., `"US"`, `"GB"`). Email and wallet address are extracted from Privy tokens. |

### Success Response (200 OK)

```json
{
  "id": "user-uuid"
}
```

**Response Fields:**

| Field | Type | Description |
|---|---|---|
| `id` | string | Platform-assigned user identifier (UUID) |

### Privy Token Claims

| Claim | Token | Description |
|---|---|---|
| `sub` | Access token | Privy user ID |
| `aud` | Access token | Privy App ID (must match your configured App ID) |
| `linked_accounts` | Identity token | Array of linked wallets |

`linked_accounts` structure:

```json
{
  "linked_accounts": [
    {
      "type": "smart_wallet",
      "address": "0xA7E41d5680dE394EaA2ed417169DFf56840Fb3EE",
      "chain_type": "ethereum"
    }
  ]
}
```

### Error Responses

**Expired Privy token (401):**

```json
{
  "error_reason": "ErrorExpired",
  "error_description": "Access token is expired",
  "error_category": {
    "category": "CategoryUnauthorized",
    "http_status_code": 401
  }
}
```

**App not registered (500):**

```json
{
  "error_reason": "ErrorConfigurationInvalid",
  "error_description": "Client application not registered",
  "error_category": {
    "category": "CategoryInternalFailure",
    "http_status_code": 500
  }
}
```

---

## JWT Token Structure

### S2S Token Claims

Decoded S2S JWT payload:

```json
{
  "iss": "https://api-baas.wirexapp.com/srv",
  "sub": "your-client-uuid",
  "azp": "your-client-uuid",
  "company_id": "your-company-uuid",
  "scope": "partner:full",
  "iat": 1739525600,
  "exp": 1739612400
}
```

| Claim | Type | Description |
|---|---|---|
| `iss` | string | Issuer. `https://api-baas.wirexapp.com/srv` |
| `sub` | string | Subject -- the `client_id` (UUID) of the partner |
| `azp` | string | Authorized party -- same as `client_id` |
| `company_id` | string | Company UUID assigned during onboarding |
| `scope` | string | Permission scope. S2S tokens have `partner:full` |
| `iat` | integer | Issued-at timestamp (Unix seconds) |
| `exp` | integer | Expiration timestamp (Unix seconds). Always `iat + 172800` (48 hours) |

### User Token Claims

User tokens include user-scoped claims in addition to the standard JWT fields. The exact claims are issued by the server and should be treated as opaque — use the token as a Bearer credential, do not parse claims for business logic.

---

## Headers Reference

### Required on All Requests (except /api/v1/token)

| Header | Format | Example | Description |
|---|---|---|---|
| `Authorization` | `Bearer <token>` | `Bearer eyJhbGciOi...` | S2S or user access token |
| `X-Chain-Id` | Numeric string | `84532` | Target blockchain network ID |
| `Content-Type` | MIME type | `application/json` | Request body content type |

### User Identity Headers

Exactly one is required for user-specific endpoints:

| Header | Format | Example | Description |
|---|---|---|---|
| `X-User-Address` | Hex (EVM) or Stellar key | `0x1234...5678` | User's EOA address (not Smart Wallet) |
| `X-User-Email` | Email string | `user@example.com` | User's registered email |
| `X-User-Id` | String | `usr_abc123def456` | Platform user identifier |

### Header Selection

Provide **only one** user identity header per request. Sending multiple identity headers returns `ErrorInvalidField` ("Multiple user identifiers provided").

Recommended priority when choosing which header to use:

1. `X-User-Id` — most reliable, platform-assigned
2. `X-User-Address` — best for on-chain context
3. `X-User-Email` — fallback option

### Privy Authentication Headers

| Header | Format | Example | Description |
|---|---|---|---|
| `Authorization` | `Bearer <token>` | `Bearer eyJhbGciOiJFUzI1Ni...` | Privy access token (Bearer-prefixed) |
| `Identity` | `Bearer <token>` | `Bearer eyJhbGciOiJFUzI1Ni...` | Privy identity token (Bearer-prefixed) |

### Valid Chain ID Values

| Chain ID | Network | Environment |
|---|---|---|
| `84532` | Base Sepolia | Sandbox |
| `9223372036854775806` | Stellar Testnet | Sandbox |
| `8453` | Base | Production |
| `9223372036854775806` | Stellar | Production |

---

## Error Response Format

All errors from authentication endpoints follow this format:

```json
{
  "error_reason": "ErrorPermissionDenied",
  "error_description": "Invalid client credentials",
  "error_category": {
    "category": "CategoryUnauthorized",
    "http_status_code": 401
  },
  "error_details": [
    {"key": "field", "details": "client_secret"}
  ]
}
```

> **Note:** `error_category` is an **object** (not a string) containing `category` and `http_status_code`. `error_details` is an optional array with field-level context.

### Error Categories

| Category | HTTP Status | Retry? | Description |
|---|---|---|---|
| `CategoryValidationFailure` | 400 | No (fix request first) | Request is malformed, missing required fields, or contains invalid values. |
| `CategoryUnauthorized` | 401 | Yes (after re-auth) | Token is invalid, expired, or credentials are wrong. Obtain a new token and retry. |
| `CategoryInternalFailure` | 500 | Yes (with backoff) | Server-side error. Retry with exponential backoff. |
| `CategoryTransientFailure` | 429 | Yes (after delay) | Rate limit exceeded. Wait for `Retry-After` header value before retrying. |

### S2S Token Exchange Errors

| HTTP | Error Reason | Description |
|---|---|---|
| 400 | `ErrorMissingField` | Missing `client_id`, `client_secret`, or `grant_type` |
| 400 | `ErrorInvalidField` | Invalid value for grant type |
| 401 | `ErrorPermissionDenied` | Invalid client credentials |
| 401 | `ErrorPermissionDenied` | Client credentials access is not enabled |
| 401 | `ErrorNotSupported` | Client credentials not supported for this company type |

### S2S Request Errors (Bearer Token)

| HTTP | Error Reason | Description |
|---|---|---|
| 400 | `ErrorMissingField` | Missing Authorization Headers |
| 400 | `ErrorInvalidField` | Bearer token not in correct format |
| 401 | `ErrorExpired` | Token is expired |
| 401 | `ErrorPermissionDenied` | Token signature is not valid |
| 401 | `ErrorMissingField` | Client ID claim is missing |
| 401 | `ErrorMissingField` | Company ID claim is missing |
| 400 | `ErrorMissingField` | X-Chain-Id header is missing |
| 400 | `ErrorMissingField` | No valid user identifier provided |
| 400 | `ErrorInvalidField` | Multiple user identifiers provided (only one allowed) |
| 400 | `ErrorNotFound` | Requested user was not found |

### Privy Token Exchange Errors

| HTTP | Error Reason | Description |
|---|---|---|
| 400 | `ErrorMissingField` | Missing Authorization Headers |
| 400 | `ErrorMissingField` | Missing Identity Headers |
| 401 | `ErrorExpired` | Access token is expired |
| 401 | `ErrorExpired` | ID token is expired |
| 401 | `ErrorPermissionDenied` | Access token signature is not valid |
| 401 | `ErrorPermissionDenied` | ID token signature is not valid |
| 401 | `ErrorMissingField` | Linked accounts claim is missing |
| 400 | `ErrorMissingField` | Not all identifiers found in linked accounts |
| 400 | `ErrorAlreadyExists` | User already registered |
| 500 | `ErrorConfigurationInvalid` | Client application not registered (Privy App ID not configured) |

### User Token Errors

| HTTP | Error Reason | Description |
|---|---|---|
| 401 | `ErrorExpired` | Token is expired |
| 401 | `ErrorPermissionDenied` | Token signature is not valid |
| 401 | `ErrorMissingField` | User ID claim is missing |
| 401 | `ErrorMissingField` | User email claim is missing |
| 401 | `ErrorMissingField` | User address claim is missing |

---

## Retry Strategy

### Recommended Exponential Backoff

```
Attempt 1: Wait 1 second
Attempt 2: Wait 2 seconds
Attempt 3: Wait 4 seconds
Attempt 4: Wait 8 seconds
Attempt 5: Wait 16 seconds (max)
```

### Implementation (JavaScript)

```javascript
async function requestWithRetry(fn, maxRetries = 5) {
  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      // error_category is an object: { category: "...", http_status_code: N }
      const category = error.response?.data?.error_category?.category;

      // Do not retry validation errors
      if (category === 'CategoryValidationFailure') {
        throw error;
      }

      // Re-authenticate on unauthorized errors
      if (category === 'CategoryUnauthorized') {
        await tokenCache.refresh();
        continue;
      }

      // Retry on transient and internal failures
      if (
        category === 'CategoryTransientFailure' ||
        category === 'CategoryInternalFailure'
      ) {
        if (attempt === maxRetries) throw error;

        const retryAfter = error.response?.headers?.['retry-after'];
        const delay = retryAfter
          ? parseInt(retryAfter) * 1000
          : Math.min(1000 * Math.pow(2, attempt), 16000);

        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }

      throw error;
    }
  }
}
```

---

## Complete Integration Example

End-to-end example: authenticate, create a user, obtain a user token, and query balances.

### JavaScript (Node.js)

```javascript
const axios = require('axios');

const BASE_URL = 'https://api-baas.wirexapp.tech';
const CLIENT_ID = '9qgK7xzQirmJgZi9zOamLXQ6dQ7KpUu9';
const CLIENT_SECRET = 'BaVKTFYdYdk5urr9fuzRHKEZ3BC-pvhyANaOfDN10r_mW-MTaZ_v4tTA1IFzav6I';
const CHAIN_ID = '84532'; // Sandbox Base Sepolia

async function main() {
  // Step 1: Obtain S2S token
  const tokenResponse = await axios.post(`${BASE_URL}/api/v1/token`, {
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: 'client_credentials'
  }, {
    headers: { 'Content-Type': 'application/json' },
    timeout: 30000
  });

  const s2sToken = tokenResponse.data.access_token;
  console.log(`S2S token obtained. Expires: ${new Date(tokenResponse.data.expires_at * 1000).toISOString()}`);

  // Step 2: Create a user
  const userResponse = await axios.post(`${BASE_URL}/api/v1/user`, {
    email: 'test-user@example.com'
  }, {
    headers: {
      'Authorization': `Bearer ${s2sToken}`,
      'X-Chain-Id': CHAIN_ID,
      'Content-Type': 'application/json'
    },
    timeout: 30000
  });

  const userAddress = userResponse.data.address;
  console.log(`User created. Address: ${userAddress}`);

  // Step 3: Obtain user token
  const userTokenResponse = await axios.post(`${BASE_URL}/api/v1/user/authorize`, {}, {
    headers: {
      'Authorization': `Bearer ${s2sToken}`,
      'X-Chain-Id': CHAIN_ID,
      'X-User-Address': userAddress,
      'Content-Type': 'application/json'
    },
    timeout: 30000
  });

  const userToken = userTokenResponse.data.access_token;
  console.log(`User token obtained. Expires: ${new Date(userTokenResponse.data.expires_at * 1000).toISOString()}`);

  // Step 4: Query user balances
  const balancesResponse = await axios.get(`${BASE_URL}/api/v1/user/balances`, {
    headers: {
      'Authorization': `Bearer ${userToken}`,
      'X-Chain-Id': CHAIN_ID,
      'X-User-Address': userAddress,
      'Content-Type': 'application/json'
    },
    timeout: 30000
  });

  console.log('User balances:', JSON.stringify(balancesResponse.data, null, 2));
}

main().catch(console.error);
```

