# Wirex BaaS SDK Reference

Source: https://docs.wirexapp.com/docs/retail-sdk

## MainWalletClient adapters

Raw private key (tests / embedded wallets):

```typescript
import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { baseSepolia } from 'viem/chains';
import type { MainWalletClient } from '@wirexapp/wpay-baas-sdk';

export function createWalletClientFromKey(privateKey: `0x${string}`, rpcUrl: string): MainWalletClient {
  const account = privateKeyToAccount(privateKey);
  const client = createWalletClient({ account, chain: baseSepolia, transport: http(rpcUrl) });
  return {
    address: account.address,
    getEthereumProvider: async () => ({
      request: async ({ method, params = [] }) => {
        if (method === 'eth_accounts') return [account.address];
        if (method === 'personal_sign') {
          const [data] = params as [`0x${string}`, string];
          return client.signMessage({ account, message: { raw: data } });
        }
        if (method === 'eth_signTypedData_v4') {
          const [, json] = params as [string, string];
          const { domain, types, primaryType, message } = JSON.parse(json);
          const { EIP712Domain: _, ...filteredTypes } = types;
          return client.signTypedData({ account, domain, types: filteredTypes, primaryType, message });
        }
        return (client.transport as any).request({ method, params });
      },
    }),
  };
}
```

Privy embedded wallet:

```typescript
function getPrivyWalletClient(wallet: ConnectedWallet): MainWalletClient {
  return { address: wallet.address, getEthereumProvider: () => wallet.getEthereumProvider() };
}
```

## sdk.auth

| Method | Description |
|--------|-------------|
| `login(params)` | Login retail user (Privy or JWT) |
| `loginCompany(params)` | Login company/corporation |
| `registerUser(params)` | Register retail user |
| `registerCompany(params)` | Register company/corporation |
| `isAuthenticated()` | Valid token held |
| `getAccessToken()` | Token or `null` if expired |
| `ensureAuthenticated()` | Throws `AuthenticationError` |
| `getAuthHeaders()` | `{ Authorization, X-User-Wallet }` |
| `getUserWallet()` / `setUserWallet(wallet)` | Read / set user wallet |
| `setAuthState(response, wallet?)` | Restore auth state |
| `clearAuth()` | Logout |

## sdk.api.baas.token

| Method | Description |
|--------|-------------|
| `getToken(request)` | Exchange `client_credentials` for access token; returns `{ access_token, token_type: 'Bearer', expires_at }` |

## sdk.api.baas.user

| Method | Description |
|--------|-------------|
| `getUser()` | Current user (v1) |
| `getUserV2()` | Current user with `capabilities` array |
| `createUser(request)` | `{ email, country, wallet_address }` |
| `createRetailUser(request)` | Create retail user |
| `validateRetailUser()` | Validate retail user |
| `authorizeUser(params)` | Returns PSI token |
| `updatePhoneNumber(request)` / `confirmPhoneNumber(request)` | Phone update / OTP confirm |
| `uploadDocument(formData)` | Upload KYC document |
| `getVerificationToken()` / `getVerificationLink()` | Wirex-hosted KYC |
| `getSharingToken(request)` / `setSharingToken(request)` | SumSub sharing token |
| `updateFreshdeskId(request)` | Update Freshdesk ID |

## sdk.api.baas.wallet

| Method | Description |
|--------|-------------|
| `getWallet(request?)` | Wallet by ID or default; `{ balances: [{ token_symbol, token_address, balance }] }` |
| `getWallets()` | All wallets |
| `createGlobalWallet(request)` | Global (multi-chain deposit) wallet |

## sdk.api.baas.cards

| Method | Description |
|--------|-------------|
| `issueVirtualCard(request)` | `{ card_name }` |
| `issuePlasticCard(request)` | Physical card |
| `getCards(request?)` | `{ data: Card[] }` |
| `getCard(cardId)` | `{ id, status, card_data: { card_name, format } }` |
| `getCardTransactions(request?)` | Card transactions |
| `activateCard(cardId, request)` | Activate |
| `blockCard(cardId)` / `unblockCard(cardId)` | Block / unblock |
| `closeCard(cardId)` | Terminal state |
| `getCardDetails(cardId, request)` | PAN and expiry, action token |
| `getCardCvv(cardId, request)` | CVV, action token |
| `getCardPin(cardId, request)` | PIN, action token (physical) |
| `changeCardLimit(cardId, request)` | Spending limit |
| `changeCardName(cardId, request)` | Rename |
| `estimateCardTransfer(request)` / `executeCardTransfer(request)` | Card top-up |
| `estimateCardWithdrawal(cardId, request)` / `executeCardWithdrawal(cardId, request)` | Withdrawal from card |
| `getActive3dsRequests()` | Pending 3DS challenges (array) |
| `approve3dsRequest(transactionId)` / `decline3dsRequest(transactionId)` | 3DS decision |
| `getDeliveryCountries()` / `getDeliveryMethods(country)` | Physical delivery |
| `getOrderFees(type, country)` | Order fees |
| `createOrderFeesInvoice(type, country, request)` | Fee invoice |

## sdk.api.baas.confirmation

| Method | Description |
|--------|-------------|
| `requestSms(request)` | `{ action_type }` -> `{ session_id }` |
| `verifySms(request)` | `{ session_id, code }` -> `{ token }` |
| `verifySignature(request)` | Verify signature for action confirmation |

## sdk.api.baas.bank

| Method | Description |
|--------|-------------|
| `getAccounts(request?)` | `{ data: BankAccount[] }` |
| `activateAccount(request)` | Activate bank account |
| `estimateTransfer(request)` / `executeTransfer(request)` | Bank transfer |
| `estimateCorridorTransferV2(corridor, request)` / `executeCorridorTransferV2(corridor, request)` | SEPA / corridor transfer |

```typescript
const estimate = await sdk.api.baas.bank.estimateCorridorTransferV2('SEPA', {
  destination_amount: 100,
  recipient_id: recipientId,
  recipient_payment_details_id: paymentDetailsId,
  account_id: eurAccountId,
});
// -> { estimation_id, fee, ... }
```

## sdk.api.baas.recipients

| Method | Description |
|--------|-------------|
| `getRecipients(request?)` | `{ data: Recipient[] }` |
| `getRecipientById(recipientId)` | `{ id, personal_info: { first_name, last_name } }` |
| `getRecipientsByCatalog` / `ByCurrency` / `ByName` / `ByType` `(request)` | Filters |
| `createRecipient(request)` / `createRecipientV2(request)` | Create |
| `updateRecipient(recipientId, request)` / `deleteRecipient(recipientId)` | Update / delete |
| `createRecipientPaymentDetails(recipientId, request)` | Add payment details |
| `updateRecipientPaymentDetails(recipientId, detailsId, request)` | Update |
| `deleteRecipientPaymentDetails(recipientId, detailsId)` | Delete |
| `incrementRecipientUsage(recipientId)` | Usage counter |

```typescript
const recipient = await sdk.api.baas.recipients.createRecipient({ first_name: 'John', last_name: 'Doe', is_business: false });
await sdk.api.baas.recipients.createRecipientPaymentDetails(recipient.id, {
  type: 'Sepa', currencies: ['EUR'], sepa: { iban: 'DE89370400440532013000', bic: 'COBADEFFXXX' },
});
```

## sdk.api.baas.activity / rates / config / withdrawal

| Method | Description |
|--------|-------------|
| `activity.getFeed(request?)` | `{ data: Activity[] }`; params `page_number`, `page_size` |
| `activity.getById(request)` | One item |
| `activity.getFullStatement(request)` | `{ start, end }` Unix seconds |
| `activity.getRequestedErcWithdrawals()` | Pending ERC-20 withdrawal requests |
| `rates.getRates(request)` | Exchange rates |
| `config.getConfig()` | Client app config |
| `sdk.api.withdrawal.getWithdrawalRequests()` | Pending ERC-20 withdrawals (phase 2 `call_data`) |

## sdk.crypto.wallet

| Method | Description |
|--------|-------------|
| `getSmartWalletAddress()` | Smart (AA) wallet address |
| `getSmartWalletClient()` | Kernel client with ExecutionDelayPolicy |
| `getSmartWalletClientWithoutPolicy()` | Kernel client without policy |
| `getSmartAccountSigner()` | Smart Account signer |
| `getMainWalletClient()` | Main (EOA) wallet client |
| `sendUserOperationsAndWaitReceipt(callData, client?)` | Send UserOperation, wait for receipt |
| `sendUserOperationsWithNonceAndWaitReceipt(callData, nonce)` | With specific nonce |
| `invalidateLocalCache()` | Clear cached wallet clients |

## sdk.crypto.accountAbstraction / accountContract

| Method | Description |
|--------|-------------|
| `isPolicyInstalled()` | `ExecutionDelayPolicy` installed as root validator |
| `isExecutorInstalled()` | `FundsManagementExecutor` installed |
| `signInPolicyAndExecutor()` / `signInPolicy()` / `signInExecutor()` | Install both / policy / executor |
| `isWalletInAccounts()` / `registerInAccounts()` | Retail Accounts contract |
| `isWalletInCorporateAccounts()` / `registerInCorporateAccounts()` | Corporate (B2B) |

## sdk.crypto.transfer

| Method | Description |
|--------|-------------|
| `makeFullErc20Transfer(params)` | Both phases in one call |
| `makeErc20TransferFirstPart(params)` | Phase 1: submit withdrawal request |
| `makeErc20TransferFinal(callData)` | Phase 2: execute after delay |
| `makeErc20TransferSynthetic(params)` | Unified tokens (WUSD / WEUR) |
| `batchTransfer(params)` | Several transfers in one UserOperation |

```typescript
interface Erc20TransferParams {
  tokenAddress: `0x${string}`;
  recipientAddress: `0x${string}`;
  amount: number;
}
interface BatchTransferItem {
  to: `0x${string}`;
  amount: string;
  token: string;   // e.g. 'USDC'
  guid: string;    // unique id for deduplication
}
```

## sdk.crypto.yield

| Method | Description |
|--------|-------------|
| `fetchYieldData()` | APY, current, weekly, lifetime yield |
| `getYieldDataForGraphic()` | Time series for charts |
| `getWeeklyYield()` | Yield this week |
| `withdraw()` | Withdraw accumulated yield to wallet balance |
| `switchYieldToken(token)` | Change yield token (e.g. `'WEUR'`) |

```typescript
interface YieldData {
  tokenSymbol: string;
  apy: string;
  currentYield: string;
  weeklyYield: string;
  lifetimeYield: string;
}
```

## sdk.crypto.smartDepositAddress

| Method | Description |
|--------|-------------|
| `initializeSmartDepositAddresses(forceRefresh?)` | Create or fetch all deposit addresses |
| `getAddresses()` | Cached addresses, no API call |
| `clearAddresses()` | Clear local cache |
