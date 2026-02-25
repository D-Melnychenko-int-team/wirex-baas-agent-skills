---
name: wirex-baas-onboarding
description: "Wirex BaaS user onboarding — create users, deploy wallets, verify identity. Covers user registration (POST /api/v2/user), smart wallet deployment (ERC-4337 Account Abstraction), three KYC verification flows (Wirex Hosted, SumSub Shared, API Reliance), user profile and capabilities (GET /api/v2/user), phone confirmation, and document upload."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Onboarding Skill

## Overview

Wirex BaaS onboarding is a **three-step process** that takes a user from zero state to a fully verified participant with access to crypto, card, and banking services.

| Step | Action | Outcome |
|------|--------|---------|
| 1 | **Wallet Deployment** | Smart wallet created on-chain with Kernel v3.1, executor, and policy modules |
| 2 | **User Registration** | User record created in Wirex backend via `POST /api/v2/user` |
| 3 | **KYC Verification** | Identity verified through one of three flows; unlocks card and banking capabilities |

---

## Step 1: Smart Wallet Deployment

The wallet is an ERC-4337 Account Abstraction smart wallet built on **Kernel v3.1**. Deployment installs two modules:

- **FundsManagement Executor** -- manages on-chain fund operations for card debits, transfers, and banking flows.
- **ExecutionDelayPolicy** -- enforces a configurable time delay on sensitive operations.

Three SDK options are available:

| SDK | Chain Support | Use Case |
|-----|--------------|----------|
| **Wirex SDK** (`@wirexapp/wirexpay-sdk`) | EVM chains | Primary integration path |
| **ZeroDev SDK** | EVM chains | Alternative for existing ZeroDev users |
| **Crossmint SDK** | Stellar | Stellar-based deployments |

After deployment, a webhook fires to `POST /v2/webhooks/wallets` confirming the wallet status.

See [WALLET-DEPLOYMENT.md](references/WALLET-DEPLOYMENT.md) for the full deployment guide.

---

## Step 2: User Registration

> **WARNING:** `wallet_address` must be the user's **EOA address** (signer), NOT the Smart Wallet address.

### Standard Registration (S2S)

```
POST /api/v2/user
```

**Required headers:** `Authorization: Bearer {s2s_token}`, `Content-Type: application/json`, `X-Chain-Id: {chainId}`

> **IMPORTANT:** `sharing_data` and `initial_data` are **mutually exclusive** — do not provide both in the same request.

#### Hosted KYC Request

```json
{
  "wallet_address": "0xAbC123...EOA",
  "initial_data": {
    "profile": {
      "email": "user@example.com"
    },
    "residence_address": {
      "country": "GB"
    }
  }
}
```

#### SumSub Shared KYC Request

> Requires prior approval from Wirex (3-sided data sharing agreement with SumSub).

```json
{
  "wallet_address": "0xAbC123...EOA",
  "sharing_data": {
    "sharing_token": "eyJhbGciOi...",
    "email": "user@example.com"
  }
}
```

Phone number from SumSub verification is **automatically confirmed** (no manual phone confirmation needed).

#### Reliance KYC Request

> Requires prior Wirex approval after detailed audit.

```json
{
  "wallet_address": "0xAbC123...EOA",
  "initial_data": {
    "profile": {
      "first_name": "Jane",
      "last_name": "Doe",
      "date_of_birth": "1990-01-15",
      "nationality": "GB",
      "email": "user@example.com",
      "phone_number": "+447700900123"
    },
    "residence_address": {
      "line1": "10 Downing Street",
      "line2": "",
      "city": "London",
      "state": "England",
      "post_code": "SW1A 2AA",
      "country": "GB"
    }
  }
}
```

Phone number (E.164 with `+` prefix) provided during reliance onboarding is **automatically confirmed**.

#### Response

```json
{
  "id": "user-uuid"
}
```

### Privy Registration

For partners using Privy authentication (headers carry Privy tokens):

```
POST /api/v1/user/retail
```

```json
{
  "country": "GB"
}
```

---

## Step 3: KYC Verification

Three KYC flows are available, each suited to different integration depths.

### KYC Flow Comparison

| Aspect | Hosted | SumSub Shared | Reliance |
|--------|--------|---------------|----------|
| **Complexity** | Low | Medium | High |
| **UI Ownership** | Wirex-hosted web page | SumSub SDK in partner app | Fully partner-owned |
| **Data Collection** | Wirex collects all data | SumSub collects, shares token | Partner collects and submits |
| **Registration Fields** | `initial_data.profile.email` + `initial_data.residence_address.country` | `sharing_data.sharing_token` + `sharing_data.email` | Full `initial_data` (profile + residence_address) + documents |
| **Partner Effort** | Redirect user to URL | Integrate SumSub SDK | Build full KYC UI, upload docs |
| **Best For** | Quick MVP / low volume | Partners already using SumSub | Full white-label experience |

### Verification Statuses

| Status | Meaning | Next Action |
|--------|---------|-------------|
| `None` | KYC not started | Begin KYC flow |
| `Applied` | User submitted application | Wait for review |
| `Pending` | Additional info requested | Provide requested documents |
| `InReview` | Under manual review | Wait |
| `Approved` | KYC passed | Full access granted |
| `Canceled` | Application canceled | Re-apply |
| `Rejected` | KYC failed | Contact support or re-apply |

### KYC Completion Endpoints

After registration, direct the user to complete KYC:

| Endpoint | Returns | Use Case |
|----------|---------|----------|
| `GET /api/v1/user/verification-link` | URL string | Redirect user in browser |
| `GET /api/v1/user/verification-token` | Token string | Embed SumSub SDK in-app |

See [KYC-FLOWS.md](references/KYC-FLOWS.md) for detailed flow walkthroughs with code examples.

---

## Post-Onboarding Access

| Feature | Available After |
|---------|----------------|
| Crypto withdrawals | Wallet deployment (immediate) |
| Crypto deposits | Wallet deployment (immediate) |
| Virtual card issuance | KYC Approved |
| Physical card issuance | KYC Approved |
| SEPA banking | KYC Approved + capability active |
| ACH banking | KYC Approved + capability active |
| Faster Payments | KYC Approved + capability active |

---

## User Profile

After registration, retrieve the full user profile:

```
GET /api/v2/user
```

The response includes profile status, verification level, residence address, external provider info, and a capabilities array that governs which features the user can access.

See [USER-PROFILE.md](references/USER-PROFILE.md) for the complete profile schema and capabilities system.

---

## Webhooks

### Wallet Webhook

```
POST /v2/webhooks/wallets
```

Fires when a wallet is deployed or its status changes. Expects 2xx within 10 seconds. Failed deliveries are NOT retried.

```json
{
  "wallet_address": "0xA7E41d5680dE394EaA2ed417169DFf56840Fb3EE",
  "wallet_name": "Main Wallet",
  "wallet_status": "Confirmed",
  "wallet_type": "Primary",
  "balances": []
}
```

Wallet status values: `Confirmed` (properly configured), `Rejected` (invalid configuration), `Unknown` (indeterminate). Wallet type values: `Primary`, `Secondary`, `Global`, `Card`.

### User Webhook (Legacy)

> **Note:** This is a legacy webhook format that will be replaced with a v2 model in a future release.

```
POST /webhook/users
```

Fires when a user profile or verification status changes.
```

---

## Quick Start Checklist

1. Deploy smart wallet using one of three SDKs (see [WALLET-DEPLOYMENT.md](references/WALLET-DEPLOYMENT.md)).
2. Register user via `POST /api/v2/user` with the **EOA address** (not the smart wallet address).
3. Choose a KYC flow and complete verification (see [KYC-FLOWS.md](references/KYC-FLOWS.md)).
4. Poll `GET /api/v2/user` or listen for the user webhook to confirm `verification.status == "Approved"`.
5. Check capabilities to gate feature access (see [USER-PROFILE.md](references/USER-PROFILE.md)).
6. User is fully onboarded -- proceed to cards, transfers, or crypto operations.
