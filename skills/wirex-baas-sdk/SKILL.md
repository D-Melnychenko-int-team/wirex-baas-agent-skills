---
name: wirex-baas-sdk
description: "Wirex BaaS TypeScript/JavaScript SDK (@wirexapp/wpay-baas-sdk) — official typed npm package wrapping OAuth2 token flow, BaaS REST services, and ZeroDev Kernel account-abstraction wallet operations. Covers installation (Node >= 18, viem peer dependency), createSDK options (env, companyId, chainId, getMainWalletClient, rhinoApiKey, logging), the MainWalletClient EIP-1193 contract, three auth paths (company OAuth2, Privy, JWT), the 7-step user registration flow, sdk.api.baas.* services, sdk.crypto.* modules (ERC-20 two-phase transfers, yield, smart deposit addresses), and typed error classes. Use when writing Node/TypeScript code against Wirex BaaS instead of raw HTTP."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS TypeScript / JavaScript SDK

## Overview

`@wirexapp/wpay-baas-sdk` is the official typed SDK for Wirex BaaS. One npm package wraps the OAuth2 token flow, all BaaS REST endpoints, and on-chain Account Abstraction wallet operations (ZeroDev Kernel V3.1). It is published on npm: https://www.npmjs.com/package/@wirexapp/wpay-baas-sdk.

> This is **not** the card-data SDK. Card collection, card reveal and 3DS in a browser are covered by the PCI Compliant SDK (see the `wirex-baas-pci-sdk` skill, packages `@wirexapp/card-*`). The two are installed and versioned independently and can be used together.

Use the SDK when you write Node.js / TypeScript code. For raw HTTP integration see the other skills (`wirex-baas-auth`, `wirex-baas-onboarding`, `wirex-baas-cards`, `wirex-baas-transfers`, `wirex-baas-crypto`). The SDK does not apply to External Authorization (see `wirex-baas-external-auth`): that model has no on-chain wallet.

## Requirements

| Requirement | Notes |
|-------------|-------|
| Node.js >= 18 | Required runtime |
| `viem ^2.0.0` | Peer dependency, install separately |
| `CLIENT_ID` / `CLIENT_SECRET` | OAuth2 credentials from Wirex partner onboarding |
| `COMPANY_ID` | Company identifier in hex format |

## Install

```
npm install @wirexapp/wpay-baas-sdk
npm install viem
```

## Initialisation

```typescript
import { createSDK, type WirexPaySDK } from '@wirexapp/wpay-baas-sdk';

const sdk: WirexPaySDK = await createSDK({
  env: 'dev',                         // 'dev' = sandbox | 'prod' = production
  companyId: process.env.COMPANY_ID,  // hex company ID
  chainId: process.env.CHAIN_ID,      // optional
  getMainWalletClient: () => mainWalletClient,
  rhinoApiKey: process.env.RHINO_API_KEY, // optional: Smart Deposit Addresses
  enableLogging: false,
  logger: customLogger,               // optional, needs enableLogging: true
});
```

`createSDK` is async: always `await` it. Parameters:

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `env` | `'dev' \| 'prod'` | Yes | `dev` = `api-baas.wirexapp.tech` + Base Sepolia (84532); `prod` = `api-baas.wirexapp.com` + Base Mainnet (8453) |
| `companyId` | `string` | Yes | Company identifier in hex |
| `companyName` | `string` | No | Sent as `X-Company-Name` on the remote-config fetch; selects that company's chain / contracts / default company |
| `configUrl` | `string` | No | Explicit remote-config URL, overrides `env` |
| `chainId` | `number` | No | `8453` Base, `84532` Base Sepolia, `5042` Arc, `5042002` Arc Testnet. Defaults to remote config `defaultChain` |
| `getMainWalletClient` | `() => MainWalletClient` | Yes | Factory returning the user's embedded wallet client |
| `rhinoApiKey` | `string` | No | Only for `sdk.crypto.smartDepositAddress`; if omitted that service throws `ConfigurationError` |
| `enableLogging` | `boolean` | No | Default `false` |
| `logger` | `Logger` | No | Custom logger |

> Note: docs differ. The on-chain registration page shows `env: 'production'` / `'sandbox'` in a `createSDK` example; the SDK page and the other pages use `'dev'` / `'prod'`. Use the SDK page values (`'dev'` / `'prod'`).

### Environments

| `env` | API host | Chain |
|-------|----------|-------|
| `dev` | `api-baas.wirexapp.tech` | Base Sepolia (84532) |
| `prod` | `api-baas.wirexapp.com` | Base Mainnet (8453) |

## MainWalletClient contract

`getMainWalletClient` returns an object with `address: string` and `getEthereumProvider(): Promise<{ request(args: { method: string; params?: unknown[] }): Promise<unknown> }>`. The EIP-1193 provider must handle at minimum `eth_accounts` (resolve signer address), `personal_sign` (SIWE, auth challenges) and `eth_signTypedData_v4` (UserOperations, EIP-712). Adapter examples for a raw private key (via viem) and a Privy embedded wallet (`wallet.getEthereumProvider()`) are in [the reference](references/REFERENCE.md#mainwalletclient-adapters).

## Authentication (three paths)

### A. Company OAuth2 (client_credentials), standard B2B backend flow

```typescript
const tokenRes = await sdk.api.baas.token.getToken({
  grant_type: 'client_credentials',
  client_id: process.env.CLIENT_ID,
  client_secret: process.env.CLIENT_SECRET,
  audience: 'https://api-business.wirexpaychain.tech', // same for dev and prod
});
// -> { access_token, token_type: 'Bearer', expires_at }

sdk.auth.setAuthState(
  { access_token: tokenRes.access_token, expires_at: tokenRes.expires_at },
  userEoaWallet,
);

// after user registration: per-user PSI token
await sdk.auth.login({ authorizationToken: tokenRes.access_token, userWallet: userEoaWallet });
sdk.auth.isAuthenticated(); // true
```

After `login`, all `sdk.api.baas.*` calls use the PSI token automatically.

### B. Privy (consumer apps)

```typescript
const authResponse = await sdk.auth.login({ privy: { accessToken, identityToken } });
const userResponse = await sdk.auth.registerUser({ privy: { accessToken, identityToken }, country: 'FR' });
```

`accessToken` comes from `getAccessToken()`, `identityToken` from `useIdentityToken()` (both `@privy-io/react-auth`).

### C. JWT (own tokens or non-Privy provider)

```typescript
await sdk.auth.login({ authorizationToken: 'your-jwt-token', userWallet: userEoaWallet });
await sdk.auth.registerUser({ authorizationToken: 'your-jwt-token', country: 'FR' });
```

### Token management

`isAuthenticated()` (boolean), `getAccessToken()` (`string | null`, null if expired), `ensureAuthenticated()` (throws `AuthenticationError`), `getAuthHeaders()` (`{ Authorization, X-User-Wallet }`), `getUserWallet()`, `setUserWallet(wallet)`, `setAuthState(response, wallet?)` (restore stored state), `clearAuth()` (logout). Also `login`, `loginCompany`, `registerUser`, `registerCompany`.

## User registration flow (steps 1-5 on-chain, 6-7 API)

1. `await sdk.crypto.wallet.getSmartWalletAddress()`
2. `sdk.crypto.accountAbstraction.isPolicyInstalled()` and `isExecutorInstalled()`
3. If either is false: `sdk.crypto.accountAbstraction.signInPolicyAndExecutor()` (one UserOperation; result `receipt.transactionHash`). Separately: `signInPolicy()` (ExecutionDelayPolicy only), `signInExecutor()` (FundsManagementExecutor only).
4. Privy only (skip for JWT / OAuth2): link the smart wallet with SIWE through `useLinkWithSiwe` (`generateSiweMessage`, `linkWithSiwe` with `walletClientType: 'smart_wallet'`, `connectorType: 'kernel'`), signing with `sdk.crypto.wallet.getSmartWalletClient()`.
5. `if (!(await sdk.crypto.accountContract.isWalletInAccounts())) await sdk.crypto.accountContract.registerInAccounts();` For corporate: `registerInCorporateAccounts()`.
6. `sdk.auth.registerUser(...)` (Privy or JWT form above; the user id is `user.id`). Company: `sdk.auth.registerCompany({ authorizationToken, companyAddress, companyName, registrationCountry, registrationNumber })`. Low-level equivalent: `createUser({ email, country, wallet_address })` -> `POST /api/v1/user`.
7. `sdk.auth.login(...)` -> `POST /api/v1/user/authorize`, PSI token stored internally.

## Modules at a glance

Full method tables are in [the reference](references/REFERENCE.md).

| Namespace | Purpose |
|-----------|---------|
| `sdk.auth` | login / register / token state |
| `sdk.api.baas.token` | `getToken(request)` OAuth2 exchange |
| `sdk.api.baas.user` | `getUser`, `getUserV2` (capabilities), `createUser`, `authorizeUser`, phone, KYC documents and tokens |
| `sdk.api.baas.wallet` | `getWallet`, `getWallets`, `createGlobalWallet` |
| `sdk.api.baas.cards` | issue, list, lifecycle, details/CVV/PIN, limits, top-up and withdrawal, 3DS, delivery, order fees |
| `sdk.api.baas.confirmation` | `requestSms`, `verifySms`, `verifySignature` (action tokens) |
| `sdk.api.baas.bank` | accounts, bank and SEPA/corridor transfers |
| `sdk.api.baas.recipients` | recipient CRUD and payment details |
| `sdk.api.baas.activity` | `getFeed`, `getById`, `getFullStatement`, `getRequestedErcWithdrawals` |
| `sdk.api.baas.rates` / `config` | `getRates(request)` / `getConfig()` |
| `sdk.api.withdrawal` | `getWithdrawalRequests()` |
| `sdk.crypto.wallet` | smart wallet address / clients, UserOperations |
| `sdk.crypto.accountAbstraction` | policy and executor install |
| `sdk.crypto.accountContract` | Accounts contract registration |
| `sdk.crypto.transfer` | ERC-20 two-phase transfers, batch |
| `sdk.crypto.yield` | yield data, withdraw, switch token |
| `sdk.crypto.smartDepositAddress` | multi-chain deposit addresses (needs `rhinoApiKey`) |

## Common flows

### Check card eligibility, issue a virtual card

```typescript
const user = await sdk.api.baas.user.getUserV2();
const ok = user.capabilities.find(c => c.type === 'VisaVirtualCard')?.status === 'Active';
const card = await sdk.api.baas.cards.issueVirtualCard({ card_name: 'My Card' });
await sdk.api.baas.cards.blockCard(card.id);   // unblockCard, closeCard (irreversible)
```

### Sensitive card data (PAN / CVV / PIN) via SMS OTP action token

```typescript
const session = await sdk.api.baas.confirmation.requestSms({ action_type: 'GetCardDetails' });
const tokenRes = await sdk.api.baas.confirmation.verifySms({ session_id: session.session_id, code: userInputCode });
const details = await sdk.api.baas.cards.getCardDetails(cardId, { action_token: tokenRes.token });
// -> { card_number, expiry_date }
const cvv = await sdk.api.baas.cards.getCardCvv(cardId, { action_token: tokenRes.token }); // -> { cvv }
```

In UAT the OTP code is `000000`. For browser-side display without handling PAN yourself use the PCI SDK instead.

### ERC-20 withdrawal (two-phase, ExecutionDelayPolicy)

```typescript
const result = await sdk.crypto.transfer.makeFullErc20Transfer({
  tokenAddress: '0x...', recipientAddress: '0x...', amount: 100,
});
// result.firstPartTxHash, result.finalTxHash, result.success
```

Manual control: `makeErc20TransferFirstPart(params)` -> `sdk.api.withdrawal.getWithdrawalRequests()` (find `status === 'Requested'`, use its `call_data`) -> `makeErc20TransferFinal(callData)` after `valid_after`. Minimum delay is about 3 seconds in sandbox, longer in production. Also `makeErc20TransferSynthetic(params)` (unified WUSD/WEUR) and `batchTransfer({ items: [{ to, amount, token, guid }] })` (`guid` = unique id for deduplication).

### Activity feed

```typescript
const feed = await sdk.api.baas.activity.getFeed({ page_number: 0, page_size: 20 });
const statement = await sdk.api.baas.activity.getFullStatement({ start: 1700000000, end: 1700600000 }); // Unix seconds
```

Activity `type`: `CardTransaction`, `BankTransfer`, `Crypto`. `direction`: `Inbound`, `Outbound`.

### Smart deposit addresses

```typescript
const addresses = await sdk.crypto.smartDepositAddress.initializeSmartDepositAddresses();
// each: depositChain, depositAddress, supportedTokens[]
```

Networks: Base, Arbitrum, BNB Chain, Ethereum, Kaia, Optimism, Polygon, Solana, TRON. Without `rhinoApiKey` access throws `ConfigurationError: "rhinoApiKey is required to use smartDepositAddress."`.

## Error handling

All errors extend `SDKError`; use `instanceof`.

| Class | Cause |
|-------|-------|
| `SDKError` | Base class |
| `ConfigurationError` | Invalid or missing SDK configuration |
| `NetworkError` | HTTP failure, exposes `statusCode` |
| `ContractError` | Contract interaction failure (e.g. execution delay not expired, invalid calldata) |
| `WalletError` | Wallet client unavailable or misconfigured |
| `TransactionError` | UserOperation reverted or timed out |
| `AuthenticationError` | Token missing, expired or invalid: re-login |
| `ValidationError` | Input validation failure |

```typescript
try {
  await sdk.crypto.transfer.makeFullErc20Transfer(params);
} catch (error) {
  if (error instanceof AuthenticationError) { /* re-login */ }
  else if (error instanceof NetworkError) { console.error('HTTP', error.statusCode); }
  else if (error instanceof ContractError) { /* delay not expired or bad calldata */ }
  else if (error instanceof TransactionError) { /* reverted on-chain */ }
}
```

## Exported types

`WirexPaySDK`, `SDKConfig`, `SDKEnvironment`, `MainWalletClient`, `Logger`, `PrivyAuth`, `LoginUserParams`, `LoginCompanyParams`, `RegisterUserParams`, `RegisterCompanyParams`, `AuthResponse`, `RegisterUserResponse`, `Hex`, `TransactionHash`, `TransferRequest`, `TransferResult`, `BatchTransferItem`, `BatchTransferResult`, `YieldData`, `YieldGraphicDataPoint`, `TokenInfo`, `ContractAddresses`, `AccountStatus`, `PolicyStatus` (all from `@wirexapp/wpay-baas-sdk`).

## Documentation

- SDK: https://docs.wirexapp.com/docs/retail-sdk
- Wallet deployment: https://docs.wirexapp.com/docs/retail-onchain-registration
- Withdrawals: https://docs.wirexapp.com/docs/retail-withdrawals
- Global addresses: https://docs.wirexapp.com/docs/retail-global-addresses
- PCI SDK: https://docs.wirexapp.com/docs/retail-pci-sdk
