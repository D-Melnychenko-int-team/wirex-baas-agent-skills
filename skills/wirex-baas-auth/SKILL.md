---
name: wirex-baas-auth
description: "Wirex BaaS authentication — how to authenticate API requests. Server-to-Server OAuth2 token exchange (POST /api/v1/token), user-scoped token issuance (POST /api/v1/user/authorize), Privy-based authentication. Covers required headers (Authorization, X-Chain-Id, X-User-Address/Email/Id), token caching strategy (48h validity, 5min refresh buffer), and security best practices."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Authentication

## Overview

Wirex BaaS uses a layered authentication model with three distinct methods, each serving different integration patterns:

1. **Server-to-Server (S2S) OAuth2** -- Machine-to-machine authentication using client credentials. This is the foundation; all other auth methods build on top of it.
2. **User Token Issuance** -- Partner-issued tokens scoped to a specific user, obtained by presenting an S2S token with user identity headers.
3. **Privy Authentication** -- Third-party identity provider integration for retail user flows, using Privy access and identity tokens.

All tokens are HMAC-SHA256 signed JWTs with a 48-hour validity period. The platform recommends caching tokens and refreshing them 5 minutes before expiry.

---

## Method 1: Server-to-Server (S2S) Authentication

S2S authentication is the primary method for backend integrations. It uses the OAuth2 client credentials grant to obtain an access token.

### Endpoint

```
POST /api/v1/token
```

This is a **user-agnostic** endpoint -- no user identity headers are required.

### Request

**Headers:**

| Header | Value |
|---|---|
| `Content-Type` | `application/json` |

**Body:**

| Field | Type | Required | Description |
|---|---|---|---|
| `client_id` | string | Yes | Your partner application UUID |
| `client_secret` | string | Yes | Your partner secret |
| `grant_type` | string | Yes | Must be `client_credentials` |

### Response

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_at": 1700172800
}
```

| Field | Type | Description |
|---|---|---|
| `access_token` | string | HMAC-SHA256 signed JWT token |
| `token_type` | string | Always `Bearer` |
| `expires_at` | integer | Unix timestamp (seconds) when the token expires |

### Token Details

| Property | Value |
|---|---|
| **Algorithm** | HMAC-SHA256 (HS256) |
| **Validity** | 48 hours from issuance |
| **Scope** | `partner:full` |
| **Format** | JWT (JSON Web Token) |

---

## Method 2: User Token Issuance

User tokens are scoped to a specific user and grant access to user-specific endpoints (balances, transfers, cards, KYC). They are obtained by presenting a valid S2S token along with user identity headers.

### Endpoint

```
POST /api/v1/user/authorize
```

### Request

**Headers:**

| Header | Required | Description |
|---|---|---|
| `Authorization` | Yes | `Bearer <s2s_access_token>` |
| `X-Chain-Id` | Yes | Target chain ID (e.g., `84532` for Sandbox Base Sepolia) |
| `X-User-Address` | Yes | The user's EOA address (not the Smart Wallet address) |
| `Content-Type` | Yes | `application/json` |

**Body:** Empty or `{}`

### Response

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_at": 1700172800
}
```

The user token has the same format and validity as the S2S token but includes user-scoped claims.

---

## Method 3: Privy Authentication

Privy authentication is designed for retail user flows where users authenticate directly through a Privy-powered frontend.

### Prerequisites

1. Set up a Privy application at [privy.io](https://privy.io)
2. Provide your Privy App ID to Wirex during onboarding
3. Wirex configures your Privy App ID in your company credentials

### Token Exchange Headers

| Header | Required | Description |
|---|---|---|
| `Authorization` | Yes | `Bearer <privy_access_token>` (from Privy SDK login) |
| `Identity` | Yes | `Bearer <privy_identity_token>` (from Privy SDK login) |
| `X-Chain-Id` | Yes | Target chain ID |

Privy tokens are validated against Privy's JWKS endpoint. The `aud` claim in the access token must match your configured Privy App ID.

### User Registration via Privy

```
POST /api/v1/user/retail
```

**Body:**

```json
{
  "country": "US"
}
```

---

## User Identity Headers

For endpoints that operate on a specific user, exactly one of the following headers must be provided:

| Header | Format | Description |
|---|---|---|
| `X-User-Address` | Hex string (EVM) or Stellar public key | The user's EOA address (not the Smart Wallet address) |
| `X-User-Email` | Email string | The user's registered email address |
| `X-User-Id` | String | The platform-assigned user identifier |

**Rules:**

- Exactly one identity header is required for user-specific calls. Multiple identity headers in the same request will be rejected with `ErrorInvalidField`.
- When choosing which header to use: `X-User-Id` is most reliable, `X-User-Address` for on-chain context, `X-User-Email` as fallback.

### User-Agnostic Endpoints

| Endpoint | Method | Description |
|---|---|---|
| `/api/v1/token` | POST | S2S token exchange |
| `/api/v1/user` | POST | Create user (v1) |
| `/api/v2/user` | POST | Create user (v2) |
| `/api/v1/config` | GET | Platform configuration |
| `/api/v1/validation/rules` | GET | Validation rules |

---

## Token Caching

Tokens are valid for 48 hours but should be cached and refreshed proactively with a 5-minute buffer before expiry.

```
Token lifetime:  |<-------------- 48 hours ------------->|
                 |                                        |
Issue time       |--- Use cached token ---|--- Refresh ---|
                 t=0                    t=47h55m         t=48h
                                          ^
                                    5-min buffer
```

---

## Error Handling

### Error Response Format

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

> **Note:** `error_category` is an **object** with `category` and `http_status_code` fields. `error_details` is an optional array providing field-level error context.

### Common Authentication Errors

| Error Reason | HTTP | Category | Description |
|---|---|---|---|
| `ErrorPermissionDenied` | 401 | `CategoryUnauthorized` | Invalid credentials or token signature |
| `ErrorExpired` | 401 | `CategoryUnauthorized` | Access token has expired |
| `ErrorMissingField` | 400 | `CategoryValidationFailure` | Required field or header missing |
| `ErrorInvalidField` | 400 | `CategoryValidationFailure` | Invalid value or multiple user identifiers provided |
| `ErrorNotSupported` | 401 | `CategoryUnauthorized` | Client credentials not supported for this company type |
| `ErrorConfigurationInvalid` | 500 | `CategoryInternalFailure` | Privy App ID not registered (Privy flow) |

---

## Security Best Practices

- **Never expose `client_secret` in client-side code.** All token exchange must happen server-side.
- **Use a secrets manager** (AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager) to store credentials.
- **Cache tokens** with a 5-minute buffer before expiry to avoid request failures.
- **Always use HTTPS.** TLS 1.2 or higher is required.
- **Implement request timeouts.** 30-second timeout recommended.
- **Never log full tokens.** Truncate to first 10 characters if logging is needed.

---

## Complete Authentication Flow

1. `POST /api/v1/token` with `client_id` + `client_secret` → receive S2S token (48h validity)
2. `POST /api/v1/user/authorize` with `Bearer {s2s_token}` + `X-User-Address` + `X-Chain-Id` → receive user token (48h validity)
3. Call user-scoped endpoints (wallets, cards, transfers) with `Bearer {user_token}`

---

## References

- [Authentication Endpoint Reference](references/REFERENCE.md) -- Complete endpoint specifications, JWT claims, JavaScript code examples, token caching, and full request/response details
