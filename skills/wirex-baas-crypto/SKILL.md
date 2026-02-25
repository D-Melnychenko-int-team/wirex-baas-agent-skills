---
name: wirex-baas-crypto
description: "Wirex BaaS crypto asset management — check balances, deposit crypto, withdraw tokens. Covers wallet balance queries (GET /api/v1/wallet), unified balance model (WUSD/WEUR on Base), multi-chain deposits via Rhino.fi (9 chains: Ethereum, Arbitrum, Polygon, Optimism, BSC, Base, Kaia, TRON, Solana), ERC20 on-chain withdrawals (two-phase delay pattern), and smart contract ABI reference."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Crypto Asset Management

This skill covers crypto asset management within the Wirex Banking-as-a-Service platform: the unified balance model, wallet queries, multi-chain deposit addresses, ERC20 withdrawals, token addresses, and smart contract ABIs.

## Unified Balance Model

Wirex BaaS uses a **unified balance model** where all user funds are represented as wrapped stablecoins on the **Base chain**:

| Token  | Represents | Chain | Decimals | Ratio |
|--------|-----------|-------|----------|-------|
| WUSD   | USD       | Base  | 18       | 1:1   |
| WEUR   | EUR       | Base  | 18       | 1:1   |

All balances across the platform (card spending, bank transfers, crypto deposits) are unified into these two tokens. There is no need to manage multiple token balances or perform manual conversions.

### Token Wrapping

- **Deposits**: When a user deposits USDC, USDT, or EURC, the tokens are bridged to Base and wrapped into WUSD or WEUR at a 1:1 ratio. The wrapping process mints the corresponding W-token.
- **Withdrawals**: When a user withdraws, WUSD unwraps to USDC on Base, and WEUR unwraps to EURC on Base. The process incorporates delay verification before execution to enhance security.

### Direct Credit Minting

WUSD/WEUR can also be minted directly (without a deposit) in the following scenarios:

- **Card refunds**: Merchant refunds credit WUSD/WEUR back to the wallet.
- **Bank transfers**: Incoming SEPA or ACH transfers mint WUSD/WEUR.
- **Peer-to-peer (P2P)**: Internal transfers between Wirex users.
- **Rewards**: Cashback, referral bonuses, and promotional credits.

## Wallet Queries

### GET /api/v1/wallet

Retrieve the current wallet balances for an account.

**Headers:**

| Header          | Value                          |
|-----------------|--------------------------------|
| Authorization   | Bearer `{access_token}`        |
| Content-Type    | application/json               |
| X-User-Address  | `{user_eoa_address}`           |
| X-Chain-Id      | `{chain_id}`                   |

**Response:**

```json
{
  "balances": [
    {
      "token_symbol": "WUSD",
      "token_address": "0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2",
      "balance": "1000000000000000000",
      "reference_balance": "1.00",
      "reference_currency": "USD"
    },
    {
      "token_symbol": "WEUR",
      "token_address": "0x379e120C1921bFD8f5E0A1a3C699e7e800b66606",
      "balance": "500000000000000000",
      "reference_balance": "0.50",
      "reference_currency": "EUR"
    }
  ]
}
```

- `balance` is the raw on-chain value with 18 decimals.
- `reference_balance` is the human-readable amount.
- `reference_currency` indicates the fiat equivalent.

## Global Deposit Addresses (Multi-Chain via Rhino.fi)

Wirex uses the **Rhino.fi SDK** to generate deposit addresses across 9 supported chains. A single "global address" set allows users to receive funds on any of these networks, which are then bridged to Base and wrapped into WUSD/WEUR.

### Supported Chains

| Chain     | Bridge Time    | Address Type     |
|-----------|----------------|------------------|
| Ethereum  | 5-15 minutes   | Shared EVM       |
| Arbitrum  | 5-15 minutes   | Shared EVM       |
| Polygon   | 5-15 minutes   | Shared EVM       |
| Optimism  | 5-15 minutes   | Shared EVM       |
| BSC       | 5-15 minutes   | Shared EVM       |
| Base      | 5-15 minutes   | Shared EVM       |
| Kaia      | 5-15 minutes   | Shared EVM       |
| TRON      | 5-15 minutes   | Separate address |
| Solana    | 5-15 minutes   | Separate address |

All EVM chains share a single global deposit address. TRON and Solana get separate addresses due to architectural differences. Addresses are reusable across multiple deposits.

### Supported Deposit Tokens

| Token | Currency Equivalent |
|-------|-------------------|
| USDC  | USD               |
| USDT  | USD               |
| EURC  | EUR               |

**Minimum deposit:** 1 USD/EUR equivalent.

### Linking Global Addresses

After generating deposit addresses via the Rhino.fi SDK, link them to the Wirex account:

**POST /api/v1/wallets/global**

```json
{
  "wallet_address": "0x1234...abcd"
}
```

### Retrieving Wallets

**GET /api/v1/wallets**

Filter by `wallet_type=Global` to retrieve only global deposit addresses.

See [references/REFERENCE.md](references/REFERENCE.md) for the full Rhino.fi SDK configuration example, TRON/Solana address creation, and detailed request/response formats.

## ERC20 Withdrawals

ERC20 withdrawals use a **two-phase delay pattern** to enhance security. The flow is:

1. **Request phase**: The user initiates a withdrawal request. The smart contract records the request with a `valid_after` timestamp determined by the `ExecutionDelayPolicy`.
2. **Wait phase**: The request remains pending until the `valid_after` time is reached.
3. **Execute phase**: After the delay expires, the withdrawal can be finalized.

### Delay Values

| Operation         | Delay     |
|-------------------|-----------|
| Token transfers   | 3 seconds |
| Account changes   | 24 hours  |

### Wirex SDK Methods

The Wirex SDK (`@wirexapp/wirexpay-sdk`) provides two approaches. Methods are namespaced under `sdk.crypto.transfer`:

#### Single-call (full transfer)

```typescript
await sdk.crypto.transfer.makeFullErc20Transfer({
  tokenAddress: "0x...",
  toAddress: "0x...",
  amount: "1000000000000000000"
});
```

This method handles both phases internally, waiting for the delay to pass before executing.

#### Two-step (manual control)

```typescript
// Step 1: Initiate the request
const request = await sdk.crypto.transfer.makeErc20TransferFirstPart({
  tokenAddress: "0x...",
  toAddress: "0x...",
  amount: "1000000000000000000"
});

// Step 2: After valid_after time has passed
await sdk.crypto.transfer.makeErc20TransferFinal(request);
```

This approach gives the integrator control over the waiting period and allows for UI updates or user confirmations between steps.

### Pending Withdrawal Requests

**GET /api/v1/withdrawal/requests** (or via `sdk.api.withdrawal.getWithdrawalRequests()`)

Returns all pending withdrawal requests for the account, including:

| Field            | Description                                                        |
|------------------|--------------------------------------------------------------------|
| account_address  | The sender's account address                                       |
| token_address    | The ERC20 token being withdrawn                                    |
| to_address       | The destination address                                            |
| amount           | The raw amount (18 decimals)                                       |
| valid_after      | ISO 8601 timestamp after which execution is valid (e.g., `"2024-01-01T12:05:00.000Z"`) |
| valid_before     | ISO 8601 timestamp after which the request expires                 |
| hash             | The request hash for identification                                |
| call_data        | Encoded transaction data for execution                             |

## Webhooks

Wirex BaaS emits webhooks for crypto-related events:

| Webhook Endpoint              | Purpose                              |
|-------------------------------|--------------------------------------|
| /v2/webhooks/activities       | Deposit and transfer activity events |
| /v2/webhooks/balances         | Balance change notifications         |
| /v2/webhooks/erc-withdrawals  | ERC20 withdrawal status updates      |

See [references/REFERENCE.md](references/REFERENCE.md) for full webhook payload examples.

## Token Addresses

See [overview ENVIRONMENTS.md](../wirex-baas-overview/references/ENVIRONMENTS.md) for complete token address tables (sandbox and production, Base and Stellar). Sandbox token addresses are also in the [sandbox skill](../wirex-baas-sandbox/SKILL.md).

## ABI Reference

Smart contract ABIs for ContractRegistry, Accounts, TokensRegistry, Kernel, and ERC20 are documented in [references/ABI-REFERENCE.md](references/ABI-REFERENCE.md).
