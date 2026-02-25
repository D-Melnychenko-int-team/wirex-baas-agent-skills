# Wallet Deployment Reference

## Architecture Overview

Wirex BaaS wallets are **ERC-4337 Account Abstraction smart wallets** built on the **Kernel v3.1 Smart Account** framework. Each wallet is deployed with two mandatory modules:

| Module | Role | Description |
|--------|------|-------------|
| **FundsManagement Executor** | Fund operations | Handles on-chain debits for card transactions, transfer routing, and banking settlement flows |
| **ExecutionDelayPolicy** | Security | Enforces a configurable time delay on sensitive operations (e.g., large withdrawals, module changes) |

### Smart Account Structure

**Kernel v3.1 Smart Account** contains: Root Validator (ECDSA owner) + FundsManagement Executor (module type 2) + ExecutionDelayPolicy (module type 1).

The **EOA (Externally Owned Account)** serves as the root validator / owner. The smart wallet address is derived deterministically from the EOA and the account factory parameters.

---

## Deployment Options

### Option 1: Wirex SDK (`@wirexapp/wirexpay-sdk`)

This is the **primary and recommended** integration path for EVM chains.

#### Installation

```bash
npm install @wirexapp/wirexpay-sdk
```

#### SDK Configuration

```typescript
import { createSDK } from '@wirexapp/wirexpay-sdk';

const sdk = await createSDK({
  env: 'production', // or 'sandbox'
  companyId: '0x00000000000000000000000000000007', // partner_id
  enableLogging: true,
  getMainWalletClient: async () => {
    return mainWalletClient; // User's EOA from Privy, WalletConnect, etc.
  },
});
```

#### SDK Methods

| Module | Method | Purpose |
|--------|--------|---------|
| `sdk.crypto.accountAbstraction` | `isPolicyInstalled()` | Check if ExecutionDelayPolicy is installed |
| `sdk.crypto.accountAbstraction` | `isExecutorInstalled()` | Check if FundsManagement Executor is installed |
| `sdk.crypto.accountAbstraction` | `signInPolicyAndExecutor()` | Install both modules in a single UserOp |
| `sdk.crypto.accountAbstraction` | `signInPolicy()` | Install policy only |
| `sdk.crypto.accountAbstraction` | `signInExecutor()` | Install executor only |
| `sdk.crypto.accountContract` | `isWalletInAccounts()` | Check if registered in on-chain accounts |
| `sdk.crypto.accountContract` | `registerInAccounts()` | Register in on-chain accounts |
| `sdk.crypto.wallet` | `getSmartWalletClient()` | Get Kernel account client |

#### Full Deployment Flow (Wirex SDK)

```typescript
import { createSDK } from '@wirexapp/wirexpay-sdk';
import { createWalletClient, http } from 'viem';
import { base } from 'viem/chains';
import { privateKeyToAccount } from 'viem/accounts';

// 1. Create signer from EOA private key
const account = privateKeyToAccount('0xYOUR_PRIVATE_KEY');
const mainWalletClient = createWalletClient({
  account,
  chain: base,
  transport: http('https://mainnet.base.org'),
});

// 2. Initialize SDK
const sdk = await createSDK({
  env: 'production', // or 'sandbox'
  companyId: '0x00000000000000000000000000000007', // partner_id
  enableLogging: true,
  getMainWalletClient: async () => mainWalletClient,
});

// 3. Check current module state
const policyInstalled = await sdk.crypto.accountAbstraction.isPolicyInstalled();
const executorInstalled = await sdk.crypto.accountAbstraction.isExecutorInstalled();

console.log(`Policy installed: ${policyInstalled}`);
console.log(`Executor installed: ${executorInstalled}`);

// 4. Deploy wallet with modules (if not already installed)
if (!policyInstalled || !executorInstalled) {
  await sdk.crypto.accountAbstraction.signInPolicyAndExecutor();
  console.log('Wallet deployed with modules.');
}

// 5. Register in on-chain accounts registry
const isRegistered = await sdk.crypto.accountContract.isWalletInAccounts();
if (!isRegistered) {
  await sdk.crypto.accountContract.registerInAccounts();
  console.log('Wallet registered in Accounts contract.');
}

console.log('Wallet deployment complete.');
```

---

### Option 2: ZeroDev SDK

For partners already using the ZeroDev ecosystem.

#### Dependencies

```bash
npm install @zerodev/sdk @zerodev/ecdsa-validator permissionless viem
```

#### Configuration

```typescript
import { createKernelAccount, createKernelAccountClient, createZeroDevPaymasterClient } from '@zerodev/sdk';
import { signerToEcdsaValidator } from '@zerodev/ecdsa-validator';
import { http, createPublicClient } from 'viem';
import { polygon } from 'viem/chains';
import { ENTRYPOINT_ADDRESS_V07 } from 'permissionless';

const config = {
  bundlerRpc: 'https://bundler.wirexpay.com/v1/polygon',
  paymasterRpc: 'https://paymaster.wirexpay.com/v1/polygon',
  rpcUrl: 'https://polygon-rpc.com',
  contractRegistryAddress: '0xContractRegistryAddress',
  partnerId: 'partner-abc',
};
```

#### Key Functions

```typescript
// Create public client
const publicClient = createPublicClient({
  chain: polygon,
  transport: http(config.rpcUrl),
});

// Create ECDSA validator from signer
const ecdsaValidator = await signerToEcdsaValidator(publicClient, {
  signer: account,        // LocalAccount from viem
  entryPoint: ENTRYPOINT_ADDRESS_V07,
});

// Create Kernel account
const kernelAccount = await createKernelAccount(publicClient, {
  plugins: {
    sudo: ecdsaValidator,
  },
  entryPoint: ENTRYPOINT_ADDRESS_V07,
  kernelVersion: '0.3.1', // Kernel v3.1
});

// Create account client with paymaster
const kernelClient = createKernelAccountClient({
  account: kernelAccount,
  chain: polygon,
  entryPoint: ENTRYPOINT_ADDRESS_V07,
  bundlerTransport: http(config.bundlerRpc),
  middleware: {
    sponsorUserOperation: async ({ userOperation }) => {
      const paymasterClient = createZeroDevPaymasterClient({
        chain: polygon,
        transport: http(config.paymasterRpc),
        entryPoint: ENTRYPOINT_ADDRESS_V07,
      });
      return paymasterClient.sponsorUserOperation({
        userOperation,
        entryPoint: ENTRYPOINT_ADDRESS_V07,
      });
    },
  },
});

// Install modules via UserOp
const installTxHash = await kernelClient.sendUserOperation({
  userOperation: {
    callData: encodeFunctionData({
      // ... install executor and policy calls
    }),
  },
});
```

---

### Option 3: Crossmint SDK (Stellar)

For Stellar-based deployments using the Crossmint infrastructure.

#### Setup

```typescript
import { CrossmintWalletSDK } from '@crossmint/wallet-sdk';

const crossmint = CrossmintWalletSDK.init({
  apiKey: 'YOUR_CROSSMINT_API_KEY',
  chain: 'stellar',
  environment: 'production', // or 'staging'
});

// Create wallet for user
const wallet = await crossmint.createWallet({
  userId: 'user-identifier',
  linkedUser: {
    email: 'user@example.com',
  },
});

console.log(`Stellar wallet address: ${wallet.address}`);
```

> **Note:** Stellar wallets follow a different on-chain model. The FundsManagement and ExecutionDelayPolicy modules are specific to EVM chains. Stellar integration uses Crossmint's custodial abstraction layer.

---

## On-Chain Flow Sequence (8 Steps)

The complete on-chain deployment follows this sequence:

| Step | Action | Transaction Type | Description |
|------|--------|-----------------|-------------|
| 1 | **Create EOA** | Off-chain | Generate or import an EOA keypair |
| 2 | **Compute Smart Account Address** | Off-chain | Deterministically derive the smart wallet address from EOA + factory params |
| 3 | **Deploy Smart Account** | UserOperation | Send the first UserOp; the EntryPoint deploys the Kernel v3.1 account via the factory |
| 4 | **Install ExecutionDelayPolicy** | UserOperation | Install the policy module (module type 1) into the kernel |
| 5 | **Install FundsManagement Executor** | UserOperation | Install the executor module (module type 2) into the kernel |
| 6 | **Register in Accounts Registry** | UserOperation | Call `createUserAccountWithWallet(partnerId)` on Accounts contract. Emits `UserAccountCreated` event. |
| 7 | **Verify Installation** | Read call | Confirm modules are installed and root validator is correct |
| 8 | **Webhook Confirmation** | Off-chain | Wirex backend sends wallet webhook to partner |

> **Optimization:** Steps 3-5 can be batched into a single UserOperation using `signInPolicyAndExecutor()` in the Wirex SDK, reducing gas costs and latency.

---

## Wallet Webhook

When the wallet is deployed and registered, the Wirex backend fires a webhook:

```
POST /v2/webhooks/wallets
```

### Webhook Payload

```json
{
  "wallet_address": "0xA7E41d5680dE394EaA2ed417169DFf56840Fb3EE",
  "wallet_name": "Main Wallet",
  "wallet_status": "Confirmed",
  "wallet_type": "Primary",
  "balances": []
}
```

### Webhook Fields

| Field | Type | Description |
|-------|------|-------------|
| `wallet_address` | string | Smart Wallet address (0x-prefixed hex) |
| `wallet_name` | string | Display name for wallet |
| `wallet_status` | string | `Confirmed`, `Rejected`, or `Unknown` |
| `wallet_type` | string | `Primary`, `Secondary`, `Global`, or `Card` |
| `balances` | array | Token balances (empty in wallet creation webhook) |

### Wallet Status Values

| Status | Meaning |
|--------|---------|
| `Confirmed` | Wallet properly configured with required modules |
| `Rejected` | Wallet configuration invalid or incomplete |
| `Unknown` | Status could not be determined |

### Webhook Handling Rules

- Wirex expects **2xx response within 10 seconds**
- Failed deliveries are logged but **NOT automatically retried**
- Implement idempotent handlers for duplicate events
- Contact Wirex support for event replay

---

## Verification

After deployment, verify the wallet state with on-chain read calls.

### Check Module Installation

```typescript
// Check if FundsManagement Executor is installed (module type 2)
const executorInstalled = await publicClient.readContract({
  address: smartAccountAddress,
  abi: kernelAbi,
  functionName: 'isModuleInstalled',
  args: [
    2, // module type: executor
    fundsManagementAddress,
    '0x', // additional data
  ],
});

// Check if ExecutionDelayPolicy is installed (module type 1)
const policyInstalled = await publicClient.readContract({
  address: smartAccountAddress,
  abi: kernelAbi,
  functionName: 'isModuleInstalled',
  args: [
    1, // module type: policy / validator
    executionDelayPolicyAddress,
    '0x', // additional data
  ],
});
```

### Check Root Validator

```typescript
// Verify the EOA is the root validator (owner)
const rootValidator = await publicClient.readContract({
  address: smartAccountAddress,
  abi: kernelAbi,
  functionName: 'rootValidator',
});

// rootValidator should match the ECDSA validator address
console.log(`Root validator: ${rootValidator}`);
```

### Check Accounts Registry

```typescript
// Verify the wallet is registered in the accounts contract
const userAccount = await publicClient.readContract({
  address: accountsRegistryAddress,
  abi: accountsRegistryAbi,
  functionName: 'getUserAccount',
  args: [eoaAddress],
});

// userAccount should return the smart wallet address
console.log(`Registered smart wallet: ${userAccount}`);
```

### Complete Verification Example

```typescript
async function verifyWalletDeployment(
  publicClient: PublicClient,
  smartAccountAddress: `0x${string}`,
  eoaAddress: `0x${string}`,
  fundsManagementAddress: `0x${string}`,
  executionDelayPolicyAddress: `0x${string}`,
  accountsRegistryAddress: `0x${string}`,
): Promise<boolean> {
  // 1. Check executor
  const executorOk = await publicClient.readContract({
    address: smartAccountAddress,
    abi: kernelAbi,
    functionName: 'isModuleInstalled',
    args: [2, fundsManagementAddress, '0x'],
  });

  // 2. Check policy
  const policyOk = await publicClient.readContract({
    address: smartAccountAddress,
    abi: kernelAbi,
    functionName: 'isModuleInstalled',
    args: [1, executionDelayPolicyAddress, '0x'],
  });

  // 3. Check accounts registry
  const registeredWallet = await publicClient.readContract({
    address: accountsRegistryAddress,
    abi: accountsRegistryAbi,
    functionName: 'getUserAccount',
    args: [eoaAddress],
  });

  const registryOk =
    registeredWallet.toLowerCase() === smartAccountAddress.toLowerCase();

  console.log(`Executor installed: ${executorOk}`);
  console.log(`Policy installed: ${policyOk}`);
  console.log(`Registry correct: ${registryOk}`);

  return executorOk && policyOk && registryOk;
}
```

---

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| `signInPolicyAndExecutor()` reverts | Insufficient gas sponsorship or invalid bundler URL | Verify `bundlerRpc` and `paymasterRpc` are correct and the partner account has sponsorship credits |
| `isModuleInstalled` returns `false` after deployment | Transaction not yet confirmed | Wait for block confirmation; poll with a short delay |
| `registerInAccounts()` fails | Wallet not yet deployed on-chain | Ensure the deploy UserOp is confirmed before calling register |
| Webhook not received | Webhook URL not configured or unreachable | Verify webhook endpoint in partner dashboard; check firewall rules |
| Smart wallet address mismatch | Wrong factory params or chain ID | Ensure `chainId`, `contractRegistryAddress`, and `partnerId` match the target environment |
