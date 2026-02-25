# Sandbox Helper API Reference

Complete endpoint reference for the Wirex BaaS sandbox Helper API at `https://ramc.wirexapp.tech`.

**Interactive documentation:** `https://ramc.wirexapp.tech/api-docs/`

**Authentication:** The Helper API uses email for user identification. No Bearer token is required. The main BaaS API endpoints still require standard S2S authentication.

---

## Token Minting

### `POST /account/retail/mint`

Mint test stablecoins directly to a wallet address.

**Request:**

```json
{
  "chainId": "84532",
  "token": "0x7Af7cDbd557eD302F7538Db1e3d094C8BBcA665c",
  "to": "0x1234567890abcdef1234567890abcdef12345678",
  "amount": "1000"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chainId` | string | Yes | Chain ID (`84532` for Base Sepolia sandbox) |
| `token` | string | Yes | Token contract address to mint |
| `to` | string | Yes | Recipient wallet address |
| `amount` | string | Yes | Amount to mint (human-readable, not raw/wei) |

**Response (200):**

```json
{
  "txHash": "0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890",
  "success": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `txHash` | string | On-chain transaction hash |
| `success` | boolean | Whether the mint was successful |

For sandbox token addresses, see [SKILL.md](../SKILL.md#sandbox-token-addresses-base-sepolia-chain-id-84532).

**Webhooks triggered:** `/v2/webhooks/balances`

**Error Response (400):**

```json
{
  "error": "Invalid token address"
}
```

---

## SEPA Simulation

### `POST /bank/sepa/deposit`

Simulate an incoming SEPA bank deposit.

**Request:**

```json
{
  "region": "GB",
  "email": "user@example.com",
  "amount": 250.00
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | string | Yes | Region code: `"GB"` or `"EEA"` (only valid values) |
| `email` | string | Yes | Registered user email |
| `amount` | number | Yes | Deposit amount in EUR |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `type=Sepa`, `direction=Inbound`, `status=Pending`

**Error Response (400):**

```json
{
  "error": "User not found for email: user@example.com"
}
```

---

### `GET /bank/sepa/transfers/pending`

Retrieve pending SEPA transfers for a user.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `region` | string | Yes | Region code |
| `email` | string | Yes | Registered user email |

**Example Request:**

```
GET /bank/sepa/transfers/pending?region=GB&email=user@example.com
```

**Response (200):**

```json
[
  {
    "id": "txfr_001",
    "transactionId": "txn_abc123",
    "status": "Pending",
    "type": "Sepa",
    "amount": {
      "currency": "EUR",
      "value": 250.00
    },
    "createdOn": "2025-03-15T10:30:00Z"
  },
  {
    "id": "txfr_002",
    "transactionId": "txn_def456",
    "status": "Pending",
    "type": "Sepa",
    "amount": {
      "currency": "EUR",
      "value": 500.00
    },
    "createdOn": "2025-03-15T11:00:00Z"
  }
]
```

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Transfer record ID |
| `transactionId` | string | Transaction ID (use for complete/revert) |
| `status` | string | Transfer status (Pending) |
| `type` | string | Transfer type (Sepa) |
| `amount` | object | Amount with currency and value |
| `amount.currency` | string | Currency code (EUR) |
| `amount.value` | number | Transfer amount |
| `createdOn` | string (ISO 8601) | Creation timestamp |

---

### `POST /bank/sepa/transfer/complete`

Mark a pending SEPA transfer as completed.

**Request:**

```json
{
  "region": "GB",
  "email": "user@example.com",
  "transactionId": "txn_abc123"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | string | Yes | Region code |
| `email` | string | Yes | Registered user email |
| `transactionId` | string | Yes | Transaction ID from pending transfers |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `status=Completed`, `/v2/webhooks/balances`

---

### `POST /bank/sepa/transfer/revert`

Revert a completed SEPA transfer by creating an inbound reversal transaction. This can only be called after a transfer has been completed (not on pending transfers).

**Request:**

```json
{
  "region": "GB",
  "email": "user@example.com",
  "transactionId": "txn_abc123"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | string | Yes | Region code: `"GB"` or `"EEA"` |
| `email` | string | Yes | Registered user email |
| `transactionId` | string | Yes | Transaction ID of a completed transfer |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `status=Failed`

---

## ACH Simulation

### `POST /bank/ach/customer/activate`

Activate a sandbox user for ACH operations. Must be called before any ACH deposits or transfers.

**Request:**

```json
{
  "email": "user@example.com"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | Registered user email |

**Response (200):**

```json
{
  "success": true
}
```

**Error Response (400):**

```json
{
  "error": "User not found for email: user@example.com"
}
```

---

### `POST /bank/ach/deposit`

Simulate an incoming ACH bank deposit.

**Request:**

```json
{
  "email": "user@example.com",
  "amount": 500.00
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | Registered user email (must be ACH-activated) |
| `amount` | number | Yes | Deposit amount in USD |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `type=AchPush`, `direction=Inbound`, `status=Pending`

**Error Response (400):**

```json
{
  "error": "ACH customer not activated for email: user@example.com"
}
```

---

### `POST /bank/ach/transfer/complete`

Mark a pending ACH transfer as completed.

**Request:**

```json
{
  "externalId": "act_abc123def456"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `externalId` | string | Yes | Activity ID from the activity webhook or activity feed |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `status=Completed`, `/v2/webhooks/balances`

---

### `POST /bank/ach/transfer/revert`

Revert an ACH transfer by creating an inbound reversal transaction that credits the funds back to the user's account.

**Request:**

```json
{
  "externalId": "act_abc123def456"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `externalId` | string | Yes | Activity ID from the activity webhook or activity feed |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `status=Failed`

---

## Card Transaction Simulation

All card transaction endpoints share the same request and response format. The only difference is the transaction type.

### Common Request Format

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cardId` | string (UUID) | Yes | Card identifier |
| `amount` | number | Yes | Transaction amount |

### Common Response Format (200)

```json
{
  "success": true,
  "transactionType": "POS",
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 25.50
}
```

| Field | Type | Description |
|-------|------|-------------|
| `success` | boolean | Whether the transaction was simulated successfully |
| `transactionType` | string | Type of transaction (POS, EPOS, ATM, Credit) |
| `cardId` | string | Card identifier |
| `amount` | number | Transaction amount |

### `POST /card/transaction/pos`

Simulate an in-store point-of-sale card purchase.

**Request:**

```json
{
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 25.50
}
```

**Response (200):**

```json
{
  "success": true,
  "transactionType": "POS",
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 25.50
}
```

---

### `POST /card/transaction/epos`

Simulate an electronic/online point-of-sale card purchase.

**Request:**

```json
{
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 49.99
}
```

**Response (200):**

```json
{
  "success": true,
  "transactionType": "EPOS",
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 49.99
}
```

---

### `POST /card/transaction/atm`

Simulate an ATM cash withdrawal.

**Request:**

```json
{
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 100.00
}
```

**Response (200):**

```json
{
  "success": true,
  "transactionType": "ATM",
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 100.00
}
```

---

### `POST /card/transaction/credit`

Simulate a card credit (refund or cashback). Unlike debit transactions, this **adds funds** to the card/wallet balance.

**Request:**

```json
{
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 15.00
}
```

**Response (200):**

```json
{
  "success": true,
  "transactionType": "Credit",
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 15.00
}
```

---

### Card Transaction Webhooks

All card transactions trigger the following webhooks:

| Webhook | Payload |
|---------|---------|
| `/v2/webhooks/activities` | Activity with `type=CardTransaction`, direction depends on debit/credit |
| `/v2/webhooks/balances` | Updated wallet balance |
| `/v2/webhooks/card-limits` | Updated daily/monthly/lifetime usage |

---

## Error Handling

All Helper API errors follow a consistent format.

**Error Response Format:**

```json
{
  "error": "Descriptive error message"
}
```

**Common Error Scenarios:**

| HTTP Status | Error Message | Cause |
|-------------|--------------|-------|
| 400 | `Missing required parameters` | Required fields not provided in request |
| 400 | `Invalid token address` | Token address not recognized on the chain |
| 500 | `User not found for email: ...` | Email not registered in sandbox |
| 500 | `ACH customer not activated for email: ...` | ACH activation required first |
| 500 | `Card not found: ...` | Card ID does not exist |
| 500 | `Transaction not found: ...` | Transaction/external ID not found |
| 500 | `Insufficient balance` | Wallet does not have enough funds for debit |
| 500 | `Internal server error` | Unexpected server-side failure |

---

## Code Examples

### JavaScript (Node.js) -- Full Test Workflow

```javascript
const HELPER_BASE = "https://ramc.wirexapp.tech";
const BAAS_API = "https://api-baas.wirexapp.tech";

// Step 1: Get S2S token from main BaaS API
async function getToken() {
  const res = await fetch(`${BAAS_API}/api/v1/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: "9qgK7xzQirmJgZi9zOamLXQ6dQ7KpUu9",
      client_secret: "BaVKTFYdYdk5urr9fuzRHKEZ3BC-pvhyANaOfDN10r_mW-MTaZ_v4tTA1IFzav6I",
      grant_type: "client_credentials",
    }),
  });
  const data = await res.json();
  return data.access_token;
}

// Step 2: Mint tokens via Helper API
async function mintTokens(to, amount) {
  const res = await fetch(`${HELPER_BASE}/account/retail/mint`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chainId: "84532",
      token: "0x7Af7cDbd557eD302F7538Db1e3d094C8BBcA665c",
      to,
      amount: String(amount),
    }),
  });
  if (!res.ok) {
    const err = await res.json();
    throw new Error(`Mint failed: ${err.error}`);
  }
  return res.json();
}

// Step 3: SEPA deposit and complete
async function sepaFlow(email, amount) {
  // Deposit
  await fetch(`${HELPER_BASE}/bank/sepa/deposit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ region: "GB", email, amount }),
  });

  // Get pending transfers
  const pendingRes = await fetch(
    `${HELPER_BASE}/bank/sepa/transfers/pending?region=GB&email=${encodeURIComponent(email)}`
  );
  const pending = await pendingRes.json();
  console.log("Pending SEPA transfers:", pending);

  // Complete the first pending transfer
  if (pending.length > 0) {
    await fetch(`${HELPER_BASE}/bank/sepa/transfer/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        region: "GB",
        email,
        transactionId: pending[0].transactionId,
      }),
    });
    console.log("SEPA transfer completed");
  }
}

// Step 4: ACH deposit workflow
async function achFlow(email, amount) {
  // Activate ACH customer
  await fetch(`${HELPER_BASE}/bank/ach/customer/activate`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email }),
  });

  // Deposit
  await fetch(`${HELPER_BASE}/bank/ach/deposit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email, amount }),
  });
  console.log("ACH deposit initiated");
}

// Step 5: Card transaction workflow
async function cardFlow(cardId) {
  // POS purchase
  const pos = await fetch(`${HELPER_BASE}/card/transaction/pos`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cardId, amount: 25.50 }),
  });
  console.log("POS transaction:", await pos.json());

  // EPOS purchase
  const epos = await fetch(`${HELPER_BASE}/card/transaction/epos`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cardId, amount: 49.99 }),
  });
  console.log("EPOS transaction:", await epos.json());

  // Credit (refund)
  const credit = await fetch(`${HELPER_BASE}/card/transaction/credit`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ cardId, amount: 10.00 }),
  });
  console.log("Credit transaction:", await credit.json());
}

// Run full test
async function main() {
  try {
    const token = await getToken();
    console.log("S2S token obtained");

    await mintTokens("0x1234...", 1000);
    console.log("Tokens minted");

    await sepaFlow("testuser@example.com", 250.00);
    await achFlow("testuser@example.com", 500.00);
    await cardFlow("550e8400-e29b-41d4-a716-446655440000");
  } catch (err) {
    console.error("Test failed:", err.message);
  }
}

main();
```

