# Wirex BaaS Environments Reference

Complete reference for all Wirex BaaS environments, blockchain networks, contract addresses, token configurations, and sandbox test credentials.

---

## API Environments

### Core API

| Environment | Base URL | Description |
|---|---|---|
| Sandbox | `https://api-baas.wirexapp.tech` | Development and testing environment. Uses testnet blockchains and test credentials. No real funds are processed. |
| Production | `https://api-baas.wirexapp.com` | Live environment with real funds and mainnet blockchains. Requires production credentials from Wirex onboarding. |

### PCI-Compliant Card API

These endpoints handle sensitive card data (PANs, CVVs) and are hosted in PCI DSS-compliant infrastructure, specifically for card tokenization in push-to-card transfers. They require separate authentication and must be accessed only from PCI-compliant systems.

| Environment | Base URL | Description |
|---|---|---|
| PCI Sandbox | `https://wx-acquiring-card-manager-uat.wirexapp.com` | Card testing with test card numbers |
| PCI Production | `https://wx-acquiring-card-manager.wirexapp.com` | Live card operations with real Visa cards |

### Helper API

| Environment | Base URL | Description |
|---|---|---|
| Helper API (Sandbox only) | `https://ramc.wirexapp.tech` | Simulates external events (bank deposits, transfer completions, card transactions). This API is available in Sandbox only and does not exist in Production. |

---

## Blockchain Networks

### Production Networks

| Network | Chain ID | Type | Explorer |
|---|---|---|---|
| **Base** | `8453` | EVM (Ethereum L2) | `https://basescan.org` |
| **Stellar** | `9223372036854775806` | Stellar Protocol | `https://stellar.expert` |

### Sandbox Networks

| Network | Chain ID | Type | Explorer |
|---|---|---|---|
| **Base Sepolia** | `84532` | EVM Testnet | `https://sepolia.basescan.org` |
| **Stellar Testnet** | `9223372036854775806` | Stellar Testnet | `https://stellar.expert/explorer/testnet` |

> **Important:** The Stellar chain ID value `9223372036854775806` is identical in both sandbox and production. The API base URL determines which network is actually used. Always ensure your base URL matches your intended environment.

---

## Sandbox Test Credentials

The following credentials are available for sandbox development and testing:

| Credential | Value |
|---|---|
| **client_id** | `9qgK7xzQirmJgZi9zOamLXQ6dQ7KpUu9` |
| **client_secret** | `BaVKTFYdYdk5urr9fuzRHKEZ3BC-pvhyANaOfDN10r_mW-MTaZ_v4tTA1IFzav6I` |
| **partner_id** | `0x00000000000000000000000000000007` |

### Quick Authentication Test

```bash
curl -X POST "https://api-baas.wirexapp.tech/api/v1/token" \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "9qgK7xzQirmJgZi9zOamLXQ6dQ7KpUu9",
    "client_secret": "BaVKTFYdYdk5urr9fuzRHKEZ3BC-pvhyANaOfDN10r_mW-MTaZ_v4tTA1IFzav6I",
    "grant_type": "client_credentials"
  }'
```

Expected response:

```json
{
  "access_token": "eyJhbGciOiJIUzI1NiIs...",
  "token_type": "Bearer",
  "expires_at": 1700000000
}
```

---

## Contract Registry Addresses

The Contract Registry is the entry point for discovering all deployed smart contract addresses. Query the registry to obtain addresses for Accounts, FundsManagement, and other contracts.

### Sandbox Contract Registries

| Network | Chain ID | Contract Registry Address |
|---|---|---|
| **Base Sepolia** | `84532` | `0xC801a0f38E20500B5840c4927553b3409890bc3c` |
| **Stellar Testnet** | `9223372036854775806` | `CBI44PUQEKP2IAD77ZPCTN2QX2IOWOSY5VYHI3SPBN4CAZY6BHR7KIVE` |

### Production Contract Registries

| Network | Chain ID | Contract Registry Address |
|---|---|---|
| **Base** | `8453` | `0xAFa697ebC7919998AF5CdE325Fbe990dC926aae4` |
| **Stellar** | `9223372036854775806` | `CC34TW4W4NUAS54WYPSAUK7RR4LMF4RSAJV555J6ZMTPGEVPAB3A563E` |

### Contracts Available from Registry

The Contract Registry returns addresses for the following contracts:

| Contract | Purpose |
|---|---|
| **Accounts** | User account (AA wallet) deployment and management. Handles wallet creation, ownership, and recovery. |
| **FundsManagement** | Token transfers, deposits, withdrawals, and balance operations. Core financial operations contract. |
| **ExecutionDelayPolicy** | Configurable time-lock policies for high-value transactions. Provides security delays on sensitive operations. |
| **TokensRegistry** | Registry of supported tokens with addresses, decimals, and metadata. Source of truth for token configuration. |

### Querying the Registry (EVM Example)

```javascript
const { ethers } = require('ethers');

const REGISTRY_ABI = [
  'function getContract(string name) view returns (address)'
];

const provider = new ethers.JsonRpcProvider('https://sepolia.base.org');
const registry = new ethers.Contract(
  '0xC801a0f38E20500B5840c4927553b3409890bc3c',
  REGISTRY_ABI,
  provider
);

// Discover contract addresses
const accountsAddress = await registry.getContract('Accounts');
const fundsAddress = await registry.getContract('FundsManagement');
const delayPolicyAddress = await registry.getContract('ExecutionDelayPolicy');
const tokensRegistryAddress = await registry.getContract('TokensRegistry');
```

---

## Token Addresses

### Sandbox Tokens -- Base Sepolia (Chain ID: 84532)

| Token | Symbol | Address | Decimals |
|---|---|---|---|
| USD Coin | USDC | `0x7Af7cDbd557eD302F7538Db1e3d094C8BBcA665c` | 6 |
| Tether USD | USDT | `0x2C6c7c00ACa9B9D8446d107367485079b0471706` | 18 |
| Euro Coin | EURC | `0xF70461ffb413981852683657A310892227e3989e` | 6 |
| Wirex USD | WUSD | `0x0774164DC20524Bb239b39D1DC42573C3E4C6976` | 18 |
| Wirex EUR | WEUR | `0x5c55F314624718019A326F16a62A05D6C6d8C8A2` | 18 |

### Sandbox Tokens -- Stellar Testnet (Chain ID: 9223372036854775806)

| Token | Symbol | Address | Decimals |
|---|---|---|---|
| USD Coin | USDC | `CBIELTK6YBZJU5UP2WWQEUCYKLPU6AUNZ2BQ4WWFEIE3USCIHMXQDAMA` | 7 |
| Tether USD | USDT | `CDLZFC3SYJYDZT7K67VZ75HPJVIEUVNIXF47ZG2FB2RMQQVU2HHGCYSC` | 7 |
| Euro Coin | EURC | `CDTKPWPLOURQA2SGTKTUQOWRCBFJ2LMJNXA7LZJNHLGV5VIZ3VYSXMKD` | 7 |
| Wirex USD | WUSD | `CDHU56JDCPHL2DVQMOSVPJSA73XBGALZFBKN4CEDERQC5SCBXQKGY43R` | 7 |
| Wirex EUR | WEUR | `CCWPNFCVR5KGIBRMQ7LCA3DLBS3TCMZAQIHMIFKR3OSS5UFBWLXUKIKW` | 7 |

### Production Tokens -- Base (Chain ID: 8453)

| Token | Symbol | Address | Decimals |
|---|---|---|---|
| USD Coin | USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | 6 |
| Tether USD | USDT | `0xfde4C96c8593536E31F229EA8f37b2ADa2699bb2` | 6 |
| Euro Coin | EURC | `0x60a3E35Cc302bFA44Cb288Bc5a4F316Fdb1adb42` | 6 |
| Wirex USD | WUSD | `0xb4bB2032A73A53C0Aa7Dc9ee2d9658a978fA7bC2` | 18 |
| Wirex EUR | WEUR | `0x379e120C1921bFD8f5E0A1a3C699e7e800b66606` | 18 |

### Production Tokens -- Stellar (Chain ID: 9223372036854775806)

| Token | Symbol | Address | Decimals |
|---|---|---|---|
| USD Coin | USDC | `CCW67TSZV3SSS2HXMBQ5JFGCKJNXKZM7UQUWUZPUTHXSTZLEO7SJMI` | 7 |
| Tether USD | USDT | `CDMLFMKMMD7MWZP3FKUBZPVHTUEDLSX4BYGYKH4GCESXYHS3IHQ4EIG` | 7 |
| Euro Coin | EURC | `CDCYWK73YTYFJZZSJ5V7EDFNHYBG4QN3VUNG2IGD27KJDDPNCZKBCBXK` | 7 |
| Wirex USD | WUSD | `CAS3J7GYLGVE6TCARP3J58YYZBSV44TEG7YIOD4STWE6OQHBXB7HKDW5` | 7 |
| Wirex EUR | WEUR | `CA3GRDQS5WPLU36OZ7NFRHIFGN2SJPLFTHWUPDIO4VCEQ3KQYLDVK5RZ` | 7 |

> **Note on Decimals:** Base (EVM) stablecoins (USDC, EURC) use 6 decimal places. WUSD and WEUR use 18 decimal places on both sandbox and production. USDT uses 18 decimals on sandbox Base Sepolia but **6 decimals on production Base**. Stellar tokens uniformly use 7 decimal places. Always verify decimals from the on-chain `TokensRegistry` contract.

---

## Infrastructure Credentials

Three blockchain infrastructure endpoints are provided per environment. Contact Wirex to obtain the specific URLs for your integration.

| Credential | Description |
|---|---|
| **Bundler RPC URL** | ZeroDev bundler for UserOperation submission |
| **Paymaster RPC URL** | ZeroDev paymaster for gas sponsorship |
| **RPC Provider URL** | Blockchain RPC endpoint for on-chain reads and transaction monitoring |

### Rhino.fi API Key

A **Rhino.fi API Key** is provided for multi-chain deposit functionality. It is used for creating smart deposit addresses for cross-chain bridging via Rhino.fi global addresses.

> **Note:** Credentials are environment-specific. Contact Wirex to obtain dedicated credentials for your company.

---

## Environment Selection Guide

| Use Case | Environment | Base URL | Chain ID |
|---|---|---|---|
| Initial development | Sandbox | `https://api-baas.wirexapp.tech` | `84532` (Base Sepolia) |
| Stellar integration testing | Sandbox | `https://api-baas.wirexapp.tech` | `9223372036854775806` |
| Card feature testing | PCI Sandbox | `https://wx-acquiring-card-manager-uat.wirexapp.com` | `84532` |
| Pre-production validation | Sandbox | `https://api-baas.wirexapp.tech` | `84532` |
| Live Base operations | Production | `https://api-baas.wirexapp.com` | `8453` |
| Live Stellar operations | Production | `https://api-baas.wirexapp.com` | `9223372036854775806` |
| Live card operations | PCI Production | `https://wx-acquiring-card-manager.wirexapp.com` | `8453` |
