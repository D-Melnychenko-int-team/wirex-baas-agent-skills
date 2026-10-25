# Sandbox Helper API Reference

Complete endpoint reference for the Wirex BaaS sandbox Helper API at `https://ramc.wirexapp.tech`.

**Interactive documentation:** `https://ramc.wirexapp.tech/api-docs/`

**Identification:** All Helper API endpoints identify accounts by the user's email address (ACH transfer complete/revert use `externalId`). The main BaaS API endpoints still require standard S2S authentication.

---

## Token Minting

### `POST /account/retail/mint`

Mint test tokens directly to a wallet address.

**Request:**

```json
{
  "chainId": "84532",
  "token": "0x0774164DC20524Bb239b39D1DC42573C3E4C6976",
  "to": "0xA7E41d5680dE394EaA2ed417169DFf56840Fb3EE",
  "amount": "1000000000000000000"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `chainId` | string | Yes | Chain ID (`84532` for Base Sepolia sandbox) |
| `token` | string | Yes | Token contract address to mint |
| `to` | string | Yes | Destination wallet address |
| `amount` | string | Yes | Amount in the token's smallest unit -- multiply the decimal amount by `10^decimals` |

The `amount` is in the smallest unit, not whole tokens. WUSD/WEUR have 18 decimals, so 1 WUSD is `"1000000000000000000"`; USDC has 6 decimals, so 1000 USDC is `"1000000000"`.

**Response (200):**

```json
{
  "txHash": "0x28da8dec81198cd43329c92ac5b7bcb048a48495bdbc69fc1c921da72fe42939",
  "success": true
}
```

| Field | Type | Description |
|-------|------|-------------|
| `txHash` | string | On-chain transaction hash |
| `success` | boolean | Whether the mint was successful |

For sandbox token addresses, see [SKILL.md](../SKILL.md#sandbox-token-addresses-base-sepolia-chain-id-84532).

---

## SEPA Simulation

### `POST /bank/sepa/deposit`

Simulate an incoming SEPA EUR deposit to a user's account.

**Request:**

```json
{
  "region": "GB",
  "email": "alex.grey@example.com",
  "amount": 250.00
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | string | No | Region code (`GB` or `EEA`). Docs: "Always use `GB` for now." |
| `email` | string | Yes | User's email address |
| `amount` | number | Yes | Amount in EUR |

**Response (200):**

```json
{
  "success": true
}
```

**Webhooks triggered:** `/v2/webhooks/activities` with `type=Sepa`, `direction=Inbound`

---

### `GET /bank/sepa/transfers/pending`

List pending outbound SEPA transfers waiting for completion.

> **Note:** In sandbox, all outbound SEPA transfers remain in pending state indefinitely. Use `complete` or `revert` to simulate the external banking system processing the transfer.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `region` | string | No | Region code (`GB` or `EEA`). Always use `GB` for now. |
| `email` | string | Yes | User's email address |

**Example Request:**

```
GET /bank/sepa/transfers/pending?region=GB&email=alex.grey@example.com
```

**Response (200):**

```json
[
  {
    "id": "txn_abc123def456",
    "transactionId": "OP-12345",
    "status": "RELEASED",
    "type": "PAYOUT",
    "amount": {
      "currency": "EUR",
      "value": 150.00
    }
  }
]
```

Use the `id` value as `transactionId` in transfer completion/revert requests.

---

### `POST /bank/sepa/transfer/complete`

Mark a pending outbound SEPA transfer as completed.

**Request:**

```json
{
  "region": "GB",
  "email": "alex.grey@example.com",
  "transactionId": "txn_abc123def456"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `region` | string | No | Region code (`GB` or `EEA`). Always use `GB` for now. |
| `email` | string | Yes | User's email address |
| `transactionId` | string | Yes | Transaction ID from the pending list (its `id` value) |

**Response (200):** `{ "success": true }`

**Webhooks triggered:** `/v2/webhooks/activities` with `status=Completed`

---

### `POST /bank/sepa/transfer/revert`

Simulate a returned SEPA transfer. This can only be called after a transfer has been completed. Creates an inbound reversal transaction that credits the funds back to the user's account.

**Request:** same body as complete (`region`, `email`, `transactionId`).

**Response (200):** `{ "success": true }`

**Webhooks triggered:** `/v2/webhooks/activities` with `type=Sepa`, `direction=Inbound` (the reversal credit)

---

## ACH Simulation

### `POST /bank/ach/customer/activate`

Activate a user's ACH account. Required before ACH deposits can be simulated.

> **Note:** In sandbox, ACH accounts remain in pending state indefinitely after creation. Call this endpoint to simulate the external ACH provider activating the account.

**Request:**

```json
{
  "email": "alex.grey@example.com"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | User's email address |

**Response (200):** `{ "success": true }`

---

### `POST /bank/ach/deposit`

Simulate an incoming ACH USD deposit to a user's account.

**Request:**

```json
{
  "email": "alex.grey@example.com",
  "amount": 500.00
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `email` | string | Yes | User's email address |
| `amount` | number | Yes | Amount in USD |

**Response (200):** `{ "success": true }`

**Webhooks triggered:** `/v2/webhooks/activities` with `type=AchPush`, `direction=Inbound`

---

### `POST /bank/ach/transfer/complete`

Mark a pending outbound ACH transfer as completed.

> **Note:** In sandbox, all outbound ACH transfers remain in pending state indefinitely. Use `complete` or `revert` to simulate the external ACH network processing the transfer.

**Request:**

```json
{
  "externalId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `externalId` | string | Yes | Activity ID from the Wirex BaaS transfer response |

**Response (200):** `{ "success": true }`

---

### `POST /bank/ach/transfer/revert`

Simulate a returned ACH transfer. This can only be called after a transfer has been completed. Creates an inbound reversal transaction that credits the funds back to the user's account.

**Request:** `{ "externalId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890" }`

**Response (200):** `{ "success": true }`

---

## Card Transaction Simulation

Each endpoint runs a complete ISO-8583 message flow (authorization, clearing, reversal, refund, etc.) against a card and triggers `/v2/webhooks/activities` webhooks with `type=CardTransaction`.

### Common Request Format

All card flow endpoints accept the same base request:

```json
{
  "cardId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 25.50,
  "currency": "GBP",
  "settlementAmount": 25.50,
  "settlementCurrency": "GBP",
  "merchantCountry": "GBR",
  "paymentProvider": "Visa"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cardId` | string (UUID) | Yes | Card ID from Wirex BaaS |
| `amount` | number | Yes | Transaction amount |
| `currency` | string | Yes | Transaction currency (ISO 4217, e.g. `GBP`) |
| `settlementAmount` | number | Yes | Settlement (billing) amount |
| `settlementCurrency` | string | Yes | Settlement currency (ISO 4217) |
| `merchantCountry` | string | No | Merchant country (ISO 3166 alpha-3, e.g. `GBR`) |
| `paymentProvider` | string | No | `Visa`, `MasterCard`, or `VisaEFunds` |

For a same-currency purchase, set `settlementAmount`/`settlementCurrency` equal to `amount`/`currency`. To simulate FX, use different values.

`POST /card/auth-and-multi-clearing` additionally requires `clearingAmounts` (array of numbers) -- the per-clearing local amounts whose sum equals the auth amount.

### Common Response (200)

Each flow returns the ISO messages it produced. Fields are present only when the flow generates them.

```json
{
  "transactionIdentifier": "a1b2c3d4-0000-0000-0000-000000000000",
  "auth": { },
  "clearing": { },
  "refund": { },
  "reversal": { },
  "representment": { },
  "adjustment": { },
  "auths": [ ],
  "clearings": [ ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `transactionIdentifier` | string | Identifier linking the messages in this flow |
| `auth` | object | Authorization message |
| `clearing` | object | Clearing/settlement message |
| `refund` | object | Refund message |
| `reversal` | object | Reversal message |
| `representment` | object | Representment message |
| `adjustment` | object | Adjustment message |
| `auths` | array | Multiple authorizations (multi-auth flows) |
| `clearings` | array | Multiple clearings (multi-clearing flows) |

### Common Flows

| Purpose | Endpoint |
|---------|----------|
| In-store purchase (auth + clearing) | `POST /card/auth-and-clearing` |
| E-commerce / card-not-present purchase | `POST /card/epos-auth-and-clearing` |
| ATM cash withdrawal | `POST /card/atm-auth-and-clearing` |
| Standalone refund | `POST /card/standalone-refund` |
| Push funds to card (Original Credit) | `POST /card/original-credit` |
| Balance inquiry | `POST /card/balance-inquiry` |

### All Flow Endpoints

| Endpoint | Description |
|----------|-------------|
| `POST /card/auth-and-clearing` | Authorization + clearing (standard purchase) |
| `POST /card/epos-auth-and-clearing` | E-commerce (card-not-present) auth + clearing |
| `POST /card/atm-auth-and-clearing` | ATM auth + clearing |
| `POST /card/fuel-dispenser-auth-and-clearing` | Fuel dispenser (full reversal + delayed auth) + clearing |
| `POST /card/multi-auth-and-clearing` | Multiple authorizations + clearing |
| `POST /card/auth-and-multi-clearing` | One auth + multiple partial clearings (`clearingAmounts`) |
| `POST /card/auth-partial-reversal` | Auth + partial reversal |
| `POST /card/auth-full-reversal` | Auth + full reversal |
| `POST /card/auth-reversal-clearing` | Auth + reversal + clearing |
| `POST /card/standalone-reversal` | Standalone reversal |
| `POST /card/standalone-clearing` | Standalone clearing |
| `POST /card/standalone-refund` | Standalone refund |
| `POST /card/original-credit` | Original Credit Transaction (push funds to card) |
| `POST /card/auth-clearing-full-refund` | Auth + clearing + full refund |
| `POST /card/auth-clearing-partial-refund` | Auth + clearing + partial refund |
| `POST /card/check-refund` | Check refund |
| `POST /card/auth-clearing-refund-representment` | Auth + clearing + refund + representment |
| `POST /card/auth-clearing-partial-refund-representment` | Auth + clearing + partial refund + representment |
| `POST /card/auth-clearing-full-reversal-representment` | Auth + clearing + full reversal + representment |
| `POST /card/auth-clearing-partial-reversal-representment` | Auth + clearing + partial reversal + representment |
| `POST /card/auth-chargeback-clearing` | Auth + chargeback advice + clearing |
| `POST /card/auth-clearing-with-correction` | Auth + clearing with correction |
| `POST /card/credit-adjustment` | Credit adjustment |
| `POST /card/debit-adjustment` | Debit adjustment |
| `POST /card/balance-inquiry` | Balance inquiry |

> The earlier `/card/transaction/pos|epos|atm|credit` endpoints are not in the current docs.

---

## 3DS Challenge Simulation

No card flow above produces a pending 3DS request. `POST /card/3ds/initiate` raises a standalone in-app confirmation challenge; approve or decline it through the Wirex BaaS API exactly as in production (see the cards skill).

### `POST /card/3ds/initiate`

```json
{
  "cardId": "64120850-73a1-4df5-a074-d463258c9deb",
  "transactionCurrency": "USD"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `cardId` | string (UUID) | Yes | Card `id` returned by Wirex BaaS card issuance |
| `transactionCurrency` | string | No | ISO 4217 alphabetic code (`USD`, `EUR`). Default `USD` |

**Response (200):**

```json
{
  "amount": 318.67,
  "currency": "840",
  "merchant": "McCullough and Sons",
  "transactionId": "14be186b-872c-41f4-9e5b-c1dc226e78a0",
  "bin": "442601"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `transactionId` | string (UUID) | Appears as `transaction_id` in `GET /api/v1/cards/3ds/requests`; the `{transactionId}` of approve/decline |
| `amount` | number | Generated by the simulator |
| `currency` | string | ISO 4217 **numeric** code (`"840"` USD, `"978"` EUR) |
| `merchant` | string | Generated by the simulator |
| `bin` | string | First 6 digits of the card number |

> The same challenge in `GET /api/v1/cards/3ds/requests` carries the alphabetic currency (`"USD"`) and `amount` as a string (`"318.67"`). Match by `transactionId` / `transaction_id`.

**Test flow:** initiate -> `GET /api/v1/cards/3ds/requests` with the card owner's token (listed immediately, same `merchant_name`, amount and `card_last_4`) -> `POST /api/v1/cards/3ds/requests/{transactionId}/approve` or `/decline` with an empty body -> `200 {}`, the challenge leaves the pending list. A second decision returns `400` `ErrorNotFound` ("No active 3DS request for this transaction"). An undecided challenge expires 5 minutes after creation.

| HTTP Status | Body | Cause |
|-------------|------|-------|
| 400 | `{"error": "cardId is required"}` | `cardId` missing |
| 500 | `{"error": "3DS initiation failed: ..."}` | Card ID is not a Wirex BaaS sandbox card |

---

## Error Handling

All endpoints return errors in this format:

```json
{
  "error": "User not found for email: alex.grey@example.com"
}
```

| HTTP Status | Description |
|-------------|-------------|
| 400 | Missing required parameters |
| 500 | Operation failed (user not found, API error, etc.) |

---

## Code Examples

### JavaScript (Node.js) -- Full Test Workflow

```javascript
const HELPER_BASE = "https://ramc.wirexapp.tech";
const BAAS_API = "https://api-baas.wirexapp.tech";

async function post(path, body) {
  const res = await fetch(`${HELPER_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  if (!res.ok) throw new Error(`${path} failed: ${data.error}`);
  return data;
}

// Step 1: Get S2S token from main BaaS API (sandbox shared credentials)
async function getToken() {
  const res = await fetch(`${BAAS_API}/api/v1/token`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      client_id: "3fCeoWq6FOtKJBZiyorXnxE41Dqp2zKB",
      client_secret: "6FIY2GEQvdlgUEFHw4Dbii22_wCAqZ37lWV3TEMfTlkxrn8F5IbdgX9TiAvQUEsC",
      grant_type: "client_credentials",
    }),
  });
  return (await res.json()).access_token;
}

// Step 2: Mint 1000 USDC (6 decimals -> smallest unit)
const mintUsdc = (to) =>
  post("/account/retail/mint", {
    chainId: "84532",
    token: "0x7Af7cDbd557eD302F7538Db1e3d094C8BBcA665c",
    to,
    amount: "1000000000",
  });

// Step 3: SEPA deposit, then complete a pending outbound transfer
async function sepaFlow(email, amount) {
  await post("/bank/sepa/deposit", { region: "GB", email, amount });

  const pending = await (
    await fetch(`${HELPER_BASE}/bank/sepa/transfers/pending?region=GB&email=${encodeURIComponent(email)}`)
  ).json();

  if (pending.length > 0) {
    await post("/bank/sepa/transfer/complete", { region: "GB", email, transactionId: pending[0].id });
  }
}

// Step 4: ACH
async function achFlow(email, amount) {
  await post("/bank/ach/customer/activate", { email });
  await post("/bank/ach/deposit", { email, amount });
}

// Step 5: Card flows
async function cardFlow(cardId) {
  const base = {
    cardId,
    amount: 25.5,
    currency: "GBP",
    settlementAmount: 25.5,
    settlementCurrency: "GBP",
    merchantCountry: "GBR",
    paymentProvider: "Visa",
  };
  console.log(await post("/card/auth-and-clearing", base));
  console.log(await post("/card/epos-auth-and-clearing", base));
  console.log(await post("/card/standalone-refund", { ...base, amount: 10, settlementAmount: 10 }));
}
```
