# Wirex BaaS Crypto — Endpoint & Integration Reference

Detailed reference for all crypto-related endpoints, SDK integrations, webhook payloads, and token addresses.

## Table of Contents

- [Wallet Endpoint](#wallet-endpoint)
- [Global Addresses](#global-addresses)
- [Rhino.fi SDK Configuration](#rhinofi-sdk-configuration)
- [TRON and Solana Address Creation](#tron-and-solana-address-creation)
- [Withdrawal Requests Endpoint](#withdrawal-requests-endpoint)
- [Webhook Payloads](#webhook-payloads)
- [Token Addresses](#token-addresses)

---

## Wallet Endpoint

### GET /api/v1/wallet

Retrieve the current wallet balances for a given account.

**Request Headers:**

| Header          | Required | Description                          |
|-----------------|----------|--------------------------------------|
| Authorization   | Yes      | Bearer `{access_token}`             |
| Content-Type    | Yes      | `application/json`                   |
| X-User-Address  | Yes      | The user's EOA address               |
| X-Chain-Id      | Yes      | The chain ID                         |

**Response (200 OK):**

```json
{
  "balances": [
    {
      "token_symbol": "WUSD",
      "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
      "balance": "25000000000000000000",
      "reference_balance": "25.00",
      "reference_currency": "USD"
    },
    {
      "token_symbol": "WEUR",
      "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606",
      "balance": "10000000000000000000",
      "reference_balance": "10.00",
      "reference_currency": "EUR"
    }
  ]
}
```

**Field Descriptions:**

| Field              | Type   | Description                                       |
|--------------------|--------|---------------------------------------------------|
| token_symbol       | string | Token ticker (WUSD, WEUR)                         |
| token_address      | string | On-chain contract address (Base)                  |
| balance            | string | Raw balance in wei (18 decimals)                  |
| reference_balance  | string | Human-readable balance as a decimal string        |
| reference_currency | string | Fiat currency the balance represents (USD, EUR)   |

---

## Global Addresses

### POST /api/v1/wallets/global

Link a global deposit address (generated via Rhino.fi) to the account.

**Request Headers:**

| Header          | Required | Description                          |
|-----------------|----------|--------------------------------------|
| Authorization   | Yes      | Bearer `{access_token}`             |
| Content-Type    | Yes      | `application/json`                   |
| X-User-Address  | Yes      | The user's EOA address               |
| X-Chain-Id      | Yes      | The chain ID                         |

**Request Body:**

```json
{
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678"
}
```

**Response (200 OK):**

```json
{
  "id": "uuid-of-wallet-record",
  "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
  "wallet_type": "Global",
  "status": "Active",
  "created_at": "2025-01-15T10:30:00Z"
}
```

### GET /api/v1/wallets

Retrieve all wallets linked to the account.

**Request Headers:**

| Header          | Required | Description                          |
|-----------------|----------|--------------------------------------|
| Authorization   | Yes      | Bearer `{access_token}`             |
| Content-Type    | Yes      | `application/json`                   |
| X-User-Address  | Yes      | The user's EOA address               |
| X-Chain-Id      | Yes      | The chain ID                         |

**Query Parameters:**

| Parameter    | Required | Description                              |
|-------------|----------|------------------------------------------|
| wallet_type | No       | Filter by type. Use `Global` for global addresses |

**Response (200 OK):**

```json
{
  "wallets": [
    {
      "id": "uuid-of-wallet-record",
      "wallet_address": "0x1234567890abcdef1234567890abcdef12345678",
      "wallet_type": "Global",
      "status": "Active",
      "chains": [
        "Ethereum", "Arbitrum", "Polygon", "Optimism",
        "BSC", "Base", "Kaia"
      ],
      "created_at": "2025-01-15T10:30:00Z"
    }
  ]
}
```

---

## Rhino.fi SDK Configuration

The Rhino.fi SDK generates deposit addresses across multiple EVM-compatible chains. Below is the full TypeScript configuration and usage example.

```typescript
import { RhinoSdk, SupportedChains } from "@rhino.fi/sdk";

// Initialize the Rhino.fi SDK
const rhinoSdk = new RhinoSdk({
  apiKey: process.env.RHINOFI_API_KEY,
  environment: "production", // or "sandbox"
});

// Define the chains for deposit address generation
const evmChains: SupportedChains[] = [
  SupportedChains.ETHEREUM,
  SupportedChains.ARBITRUM,
  SupportedChains.POLYGON,
  SupportedChains.OPTIMISM,
  SupportedChains.BSC,
  SupportedChains.BASE,
  SupportedChains.KAIA,
];

// Step 1: Create deposit addresses for EVM chains
// All EVM chains share a single global deposit address
const depositAddressResult = await rhinoSdk.depositAddresses.create({
  depositChains: evmChains,
  destinationChain: SupportedChains.BASE,
  destinationAddress: accountWalletAddress, // user's Base wallet
  bridgeIfNotSwappable: true,
  tokenOut: 'USDC',
  postBridgeData: { _tag: 'wirexwrap' },
  reusePolicy: 'reuse-existing',
});

// The result contains a single address usable on all specified EVM chains
const globalAddress = depositAddressResult.address;
console.log("Global deposit address:", globalAddress);

// Step 2: Activate the deposit address
// Response includes an isActive field
await rhinoSdk.api.depositAddresses.activate({
  depositAddress: globalAddress,
  depositChain: SupportedChains.ETHEREUM, // activate per chain
});

// Step 3: Link the global address to the Wirex account
const response = await fetch("https://api-baas.wirexapp.com/api/v1/wallets/global", {
  method: "POST",
  headers: {
    "Authorization": `Bearer ${accessToken}`,
    "Content-Type": "application/json",
    "X-User-Address": userEoaAddress,
    "X-Chain-Id": chainId,
  },
  body: JSON.stringify({
    wallet_address: globalAddress,
  }),
});
```

### Supported Deposit Tokens per Chain

| Chain     | USDC | USDT | EURC |
|-----------|------|------|------|
| Ethereum  | Yes  | Yes  | Yes  |
| Arbitrum  | Yes  | Yes  | No   |
| Polygon   | Yes  | Yes  | No   |
| Optimism  | Yes  | Yes  | No   |
| BSC       | No   | Yes  | No   |
| Base      | Yes  | Yes  | Yes  |
| Kaia      | Yes  | Yes  | No   |
| TRON      | No   | Yes  | No   |
| Solana    | Yes  | Yes  | No   |

---

## TRON and Solana Address Creation

TRON and Solana are not EVM-compatible and require separate address generation through the Rhino.fi SDK.

### TRON Address

```typescript
const tronResult = await rhinoSdk.depositAddresses.create({
  depositChains: [SupportedChains.TRON],
  destinationChain: SupportedChains.BASE,
  destinationAddress: accountWalletAddress,
  bridgeIfNotSwappable: true,
  tokenOut: 'USDC',
  postBridgeData: { _tag: 'wirexwrap' },
  reusePolicy: 'reuse-existing',
});

const tronAddress = tronResult.address;
console.log("TRON deposit address:", tronAddress);
// Example: TXyz1234567890abcdef1234567890ab

await rhinoSdk.api.depositAddresses.activate({
  depositAddress: tronAddress,
  depositChain: SupportedChains.TRON,
});
```

### Solana Address

```typescript
const solanaResult = await rhinoSdk.depositAddresses.create({
  depositChains: [SupportedChains.SOLANA],
  destinationChain: SupportedChains.BASE,
  destinationAddress: accountWalletAddress,
  bridgeIfNotSwappable: true,
  tokenOut: 'USDC',
  postBridgeData: { _tag: 'wirexwrap' },
  reusePolicy: 'reuse-existing',
});

const solanaAddress = solanaResult.address;
console.log("Solana deposit address:", solanaAddress);
// Example: 7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU

await rhinoSdk.api.depositAddresses.activate({
  depositAddress: solanaAddress,
  depositChain: SupportedChains.SOLANA,
});
```

Each non-EVM chain produces a unique address in its native format. These addresses must be linked to the Wirex account separately via `POST /api/v1/wallets/global`.

---

## Withdrawal Requests Endpoint

### GET /api/v1/withdrawal/requests

Retrieve all pending ERC20 withdrawal requests for the account.

**Request Headers:**

| Header          | Required | Description                          |
|-----------------|----------|--------------------------------------|
| Authorization   | Yes      | Bearer `{access_token}`             |
| Content-Type    | Yes      | `application/json`                   |
| X-User-Address  | Yes      | The user's EOA address               |
| X-Chain-Id      | Yes      | The chain ID                         |

**Response (200 OK):**

```json
{
  "data": [
    {
      "account_address": "0xabc123...def456",
      "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
      "to_address": "0x789abc...012def",
      "amount": "5000000000000000000",
      "valid_after": "2024-01-15T12:05:00.000Z",
      "valid_before": "2024-01-16T12:05:00.000Z",
      "hash": "0xdeadbeef...cafebabe",
      "call_data": "0x..."
    }
  ]
}
```

**Field Descriptions:**

| Field           | Type   | Description                                                |
|-----------------|--------|------------------------------------------------------------|
| account_address | string | The sender's smart account address on Base                 |
| token_address   | string | The ERC20 token contract address being withdrawn           |
| to_address      | string | The destination address for the withdrawal                 |
| amount          | string | Raw amount in the token's smallest unit                    |
| valid_after     | string | ISO 8601 timestamp after which execution is allowed        |
| valid_before    | string | ISO 8601 timestamp after which the request expires         |
| hash            | string | Unique hash identifying this withdrawal request            |
| call_data       | string | ABI-encoded transaction data for finalizing the withdrawal |

The `valid_after` timestamp is set by the smart contract's `ExecutionDelayPolicy`. The withdrawal cannot be finalized before this time.

---

## Webhook Payloads

See [wirex-baas-webhooks reference](../wirex-baas-webhooks/references/REFERENCE.md) for complete crypto-related webhook payloads (activity, balance, ERC withdrawal).

---

## Token Addresses

See [overview ENVIRONMENTS.md](../wirex-baas-overview/references/ENVIRONMENTS.md) for complete token address tables (sandbox and production, Base and Stellar). Always verify token addresses against the on-chain `TokensRegistry` contract before integration.
