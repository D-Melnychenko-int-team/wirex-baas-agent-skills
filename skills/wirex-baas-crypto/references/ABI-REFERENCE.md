# Wirex BaaS Crypto — Smart Contract ABI Reference

This document provides ABI details for the core smart contracts used in the Wirex BaaS platform on Base chain. Use these ABIs for direct on-chain integration or for decoding transaction data.

## Table of Contents

- [ContractRegistry](#contractregistry)
- [Accounts](#accounts)
- [TokensRegistry](#tokensregistry)
- [Kernel v3.1](#kernel-v31)
- [ERC20 Standard](#erc20-standard)

---

## ContractRegistry

The `ContractRegistry` contract serves as the central directory for all platform contracts. Query it to discover the addresses of other contracts dynamically.

### contractByName

Retrieve a contract's proxy address by its registered name.

```solidity
function contractByName(string memory name) external view returns (address proxy)
```

**Parameters:**

| Name | Type   | Description                              |
|------|--------|------------------------------------------|
| name | string | Registered contract name (e.g., "Accounts", "TokensRegistry") |

**Returns:**

| Name  | Type    | Description                |
|-------|---------|----------------------------|
| proxy | address | Proxy address of the contract |

**Example usage (ethers.js):**

```typescript
const registryAbi = [
  "function contractByName(string memory name) external view returns (address)",
  "function contracts() external view returns (tuple(string name, address proxy)[])"
];

const registry = new ethers.Contract(registryAddress, registryAbi, provider);

// Get the Accounts contract address
const accountsAddress = await registry.contractByName("Accounts");
console.log("Accounts contract:", accountsAddress);
```

### contracts

Retrieve all registered contracts as an array of (name, proxy) tuples.

```solidity
function contracts() external view returns (tuple(string name, address proxy)[] memory)
```

**Returns:**

An array of tuples, each containing:

| Field | Type    | Description              |
|-------|---------|--------------------------|
| name  | string  | Registered contract name |
| proxy | address | Proxy address            |

**Example usage:**

```typescript
const allContracts = await registry.contracts();
for (const { name, proxy } of allContracts) {
  console.log(`${name}: ${proxy}`);
}
// Output:
// Accounts: 0x...
// TokensRegistry: 0x...
// ExecutionDelayPolicy: 0x...
// ...
```

---

## Accounts

The `Accounts` contract manages user account creation, retrieval, and status tracking. Each user account is a smart contract wallet associated with a parent entity (the BaaS partner).

### createUserAccountWithWallet

Create a new user account under a parent entity. This deploys a smart account wallet for the user.

```solidity
function createUserAccountWithWallet(bytes16 parentEntity) external returns (address account)
```

**Parameters:**

| Name         | Type    | Description                                  |
|-------------|---------|----------------------------------------------|
| parentEntity | bytes16 | The BaaS partner's entity identifier (UUID)  |

**Returns:**

| Name    | Type    | Description                          |
|---------|---------|--------------------------------------|
| account | address | The newly created smart account address |

### getUserAccount

Retrieve a user account by the owner's address and parent entity.

```solidity
function getUserAccount(address owner, bytes16 parentEntity) external view returns (
  address accountAddress,
  uint8 status,
  uint8 verificationStatus
)
```

**Parameters:**

| Name         | Type    | Description                       |
|-------------|---------|-----------------------------------|
| owner        | address | The EOA owner of the account      |
| parentEntity | bytes16 | The BaaS partner's entity ID      |

**Returns:**

| Name               | Type    | Description                           |
|-------------------|---------|---------------------------------------|
| accountAddress     | address | The smart account contract address    |
| status             | uint8   | Account status code (see table below) |
| verificationStatus | uint8   | KYC verification code (see table below) |

### getWallet

Retrieve wallet information for a specific account under a parent entity.

```solidity
function getWallet(bytes16 parentEntity, address wallet) external view returns (
  address accountAddress,
  uint8 status,
  uint8 verificationStatus
)
```

**Parameters:**

| Name         | Type    | Description                       |
|-------------|---------|-----------------------------------|
| parentEntity | bytes16 | The BaaS partner's entity ID      |
| wallet       | address | The wallet address to look up     |

**Returns:**

Same as `getUserAccount`.

### UserAccountCreated Event

Emitted when a new user account is created.

```solidity
event UserAccountCreated(
  address indexed owner,
  bytes16 indexed parentEntity,
  address account
)
```

**Event Fields:**

| Field        | Type    | Indexed | Description                           |
|-------------|---------|---------|---------------------------------------|
| owner        | address | Yes     | The EOA owner of the new account      |
| parentEntity | bytes16 | Yes     | The BaaS partner's entity ID          |
| account      | address | No      | The newly created smart account address |

### Account Status Codes

| Code | Name    | Description                                |
|------|---------|--------------------------------------------|
| 0    | None    | Account does not exist                     |
| 1    | Pending | Account created, awaiting activation       |
| 2    | Active  | Account is fully operational               |
| 3    | Blocked | Account is temporarily suspended           |
| 4    | Deleted | Account has been permanently deactivated   |

### Verification Status Codes

| Code | Name     | Description                                   |
|------|----------|-----------------------------------------------|
| 0    | None     | No verification submitted                     |
| 1    | Applied  | Verification application submitted            |
| 2    | InReview | Verification is being reviewed                |
| 3    | Approved | Verification approved (KYC complete)          |
| 4    | Rejected | Verification rejected                         |

### Full ABI Fragment

```json
[
  {
    "inputs": [{ "name": "parentEntity", "type": "bytes16" }],
    "name": "createUserAccountWithWallet",
    "outputs": [{ "name": "account", "type": "address" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "owner", "type": "address" },
      { "name": "parentEntity", "type": "bytes16" }
    ],
    "name": "getUserAccount",
    "outputs": [
      { "name": "accountAddress", "type": "address" },
      { "name": "status", "type": "uint8" },
      { "name": "verificationStatus", "type": "uint8" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "parentEntity", "type": "bytes16" },
      { "name": "wallet", "type": "address" }
    ],
    "name": "getWallet",
    "outputs": [
      { "name": "accountAddress", "type": "address" },
      { "name": "status", "type": "uint8" },
      { "name": "verificationStatus", "type": "uint8" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "name": "owner", "type": "address" },
      { "indexed": true, "name": "parentEntity", "type": "bytes16" },
      { "indexed": false, "name": "account", "type": "address" }
    ],
    "name": "UserAccountCreated",
    "type": "event"
  }
]
```

---

## TokensRegistry

The `TokensRegistry` contract maintains the list of all supported tokens on the platform.

### retrieveAllTokensV2

Retrieve all registered tokens with their metadata.

```solidity
function retrieveAllTokensV2() external view returns (
  tuple(address tokenAddress, string symbol, string name, uint8 decimals, bool active)[] memory
)
```

**Returns:**

An array of tuples, each containing:

| Field        | Type    | Description                              |
|-------------|---------|------------------------------------------|
| tokenAddress | address | The token's contract address             |
| symbol       | string  | Token symbol (e.g., "WUSD", "USDC")     |
| name         | string  | Full token name                          |
| decimals     | uint8   | Number of decimals (6 for USDC, 18 for WUSD) |
| active       | bool    | Whether the token is currently active    |

**Example usage:**

```typescript
const tokensRegistryAbi = [
  "function retrieveAllTokensV2() external view returns (tuple(address tokenAddress, string symbol, string name, uint8 decimals, bool active)[])",
  "function getToken(address tokenAddress) external view returns (tuple(address tokenAddress, string symbol, string name, uint8 decimals, bool active))"
];

const tokensRegistry = new ethers.Contract(tokensRegistryAddress, tokensRegistryAbi, provider);

const allTokens = await tokensRegistry.retrieveAllTokensV2();
for (const token of allTokens) {
  console.log(`${token.symbol} (${token.tokenAddress}): ${token.decimals} decimals, active=${token.active}`);
}
```

### getToken

Retrieve metadata for a single token by its address.

```solidity
function getToken(address tokenAddress) external view returns (
  tuple(address tokenAddress, string symbol, string name, uint8 decimals, bool active) memory
)
```

**Parameters:**

| Name         | Type    | Description                    |
|-------------|---------|--------------------------------|
| tokenAddress | address | The token's contract address   |

**Returns:**

Same tuple structure as `retrieveAllTokensV2` for a single token.

### Full ABI Fragment

```json
[
  {
    "inputs": [],
    "name": "retrieveAllTokensV2",
    "outputs": [
      {
        "components": [
          { "name": "tokenAddress", "type": "address" },
          { "name": "symbol", "type": "string" },
          { "name": "name", "type": "string" },
          { "name": "decimals", "type": "uint8" },
          { "name": "active", "type": "bool" }
        ],
        "name": "",
        "type": "tuple[]"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [{ "name": "tokenAddress", "type": "address" }],
    "name": "getToken",
    "outputs": [
      {
        "components": [
          { "name": "tokenAddress", "type": "address" },
          { "name": "symbol", "type": "string" },
          { "name": "name", "type": "string" },
          { "name": "decimals", "type": "uint8" },
          { "name": "active", "type": "bool" }
        ],
        "name": "",
        "type": "tuple"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
```

---

## Kernel v3.1

The `Kernel` contract is the smart account implementation used for user wallets. It follows the ERC-7579 modular account standard. Key functions for module management and validator configuration are documented below.

### installModule

Install a module (validator, executor, hook, or fallback) on the smart account.

```solidity
function installModule(
  uint256 moduleType,
  address moduleAddress,
  bytes calldata initData
) external
```

**Parameters:**

| Name          | Type    | Description                                    |
|--------------|---------|------------------------------------------------|
| moduleType    | uint256 | Module type: 1=Validator, 2=Executor, 3=Hook, 4=Fallback |
| moduleAddress | address | Address of the module contract to install       |
| initData      | bytes   | Initialization data for the module              |

**Module Types:**

| Value | Type      | Description                                    |
|-------|-----------|------------------------------------------------|
| 1     | Validator | Validates user operations (signatures)         |
| 2     | Executor  | Executes actions on behalf of the account      |
| 3     | Hook      | Pre/post execution hooks                       |
| 4     | Fallback  | Fallback handler for unknown function calls    |

### changeRootValidator

Change the root validator of the smart account. The root validator is the primary signature validation module.

```solidity
function changeRootValidator(
  bytes21 validatorId,
  address hook,
  bytes calldata validatorData,
  bytes calldata hookData
) external
```

**Parameters:**

| Name          | Type    | Description                                    |
|--------------|---------|------------------------------------------------|
| validatorId   | bytes21 | Identifier of the new root validator module     |
| hook          | address | Hook address to attach (address(0) for none)    |
| validatorData | bytes   | Configuration data for the validator            |
| hookData      | bytes   | Configuration data for the hook                 |

### isModuleInstalled

Check whether a specific module is installed on the account.

```solidity
function isModuleInstalled(
  uint256 moduleType,
  address moduleAddress
) external view returns (bool)
```

**Parameters:**

| Name          | Type    | Description                    |
|--------------|---------|--------------------------------|
| moduleType    | uint256 | Module type (1-4)              |
| moduleAddress | address | Address of the module contract |

**Returns:**

| Type | Description                         |
|------|-------------------------------------|
| bool | `true` if the module is installed   |

### rootValidator

Get the current root validator of the smart account.

```solidity
function rootValidator() external view returns (bytes21)
```

**Returns:**

| Type    | Description                              |
|---------|------------------------------------------|
| bytes21 | The identifier of the current root validator |

### Full ABI Fragment

```json
[
  {
    "inputs": [
      { "name": "moduleType", "type": "uint256" },
      { "name": "moduleAddress", "type": "address" },
      { "name": "initData", "type": "bytes" }
    ],
    "name": "installModule",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "validatorId", "type": "bytes21" },
      { "name": "hook", "type": "address" },
      { "name": "validatorData", "type": "bytes" },
      { "name": "hookData", "type": "bytes" }
    ],
    "name": "changeRootValidator",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "moduleType", "type": "uint256" },
      { "name": "moduleAddress", "type": "address" }
    ],
    "name": "isModuleInstalled",
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "rootValidator",
    "outputs": [{ "name": "", "type": "bytes21" }],
    "stateMutability": "view",
    "type": "function"
  }
]
```

---

## ERC20 Standard

Standard ERC20 functions used for token interactions on the platform. These apply to WUSD, WEUR, USDC, USDT, and EURC.

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```

Returns the token balance of the specified account.

### transfer

```solidity
function transfer(address to, uint256 amount) external returns (bool)
```

Transfer tokens from the caller to the specified address.

### approve

```solidity
function approve(address spender, uint256 amount) external returns (bool)
```

Approve a spender to transfer up to `amount` tokens on behalf of the caller.

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```

Returns the remaining number of tokens that `spender` is allowed to transfer on behalf of `owner`.

### decimals

```solidity
function decimals() external view returns (uint8)
```

Returns the number of decimals the token uses.

### symbol

```solidity
function symbol() external view returns (string memory)
```

Returns the token symbol.

### Full ABI Fragment

```json
[
  {
    "inputs": [{ "name": "account", "type": "address" }],
    "name": "balanceOf",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "to", "type": "address" },
      { "name": "amount", "type": "uint256" }
    ],
    "name": "transfer",
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "spender", "type": "address" },
      { "name": "amount", "type": "uint256" }
    ],
    "name": "approve",
    "outputs": [{ "name": "", "type": "bool" }],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      { "name": "owner", "type": "address" },
      { "name": "spender", "type": "address" }
    ],
    "name": "allowance",
    "outputs": [{ "name": "", "type": "uint256" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "decimals",
    "outputs": [{ "name": "", "type": "uint8" }],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "symbol",
    "outputs": [{ "name": "", "type": "string" }],
    "stateMutability": "view",
    "type": "function"
  }
]
```
