# KYC Flows Reference

Wirex supports **only one verification flow at a time**; changing the configured flow may affect users who have already completed or are undergoing verification.

## Verification Levels

| Level | Description | Documents | Unlocks |
|-------|-------------|-----------|---------|
| `BDD` | Basic Due Diligence | PoI + selfie | Account creation, limited features |
| `SDD` | Standard Due Diligence | PoI + PoA + selfie | Bank accounts, cards, standard transfers; higher spending limits |
| `EDD` | Enhanced Due Diligence | Additional documentation | Higher limits, additional features |

PoI = Proof of Identity, PoA = Proof of Address. The API enum for `verification_level` is `N/A`, `BDD`, `SDD`, `XDDBridge`, `EDD`.

---

## Flow 1: Wirex Hosted KYC

The simplest integration. The partner registers the user with minimal data, then lets them complete KYC in the hosted SumSub widget or an embedded SumSub SDK.

### Step 1: Register User

Two registration methods:

| Method | Endpoint | Auth |
|--------|----------|------|
| S2S Registration | `POST /api/v2/user` | S2S token (backend-to-backend) |
| Privy Registration | `POST /api/v1/user/retail` | Privy tokens (frontend) |

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "user_address": "0xAbC123...EOA",
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

`user_address` replaces the former `wallet_address` (both accepted; if both are supplied they must match). Response: `{ "id": "<user uuid>" }`.

Privy variant: `POST /api/v1/user/retail` with `Authorization: Bearer {privy_access_token}`, `Identity: Bearer {privy_identity_token}`, `X-Chain-Id`, body `{ "country": "GB" }` (optional `referrer_address`).

> **Docs inconsistency:** the API reference schema for `POST /api/v2/user` lists `initial_data.is_pep`, every `profile` field and `residence_address` city/country/line1/post_code as required; the Hosted KYC guide (followed here) registers with only email + country. The guide's Privy example also sends `email`, while the reference body has only `country` and `referrer_address`.

### Step 2: Get Verification Link

```
POST /api/v1/user/verification-link
Authorization: Bearer {user_token}
X-Chain-Id: {chainId}
Content-Type: application/json
```

Optional body: `{ "verification_level": "SDD" }`.

**Response:**

```json
{
  "redirect_uri": "https://in.sumsub.com/idensic/l/#/HA0Z3b34F9YfWxhQ"
}
```

Open the URL in a browser or webview; the user completes verification in the hosted SumSub widget.

> **Docs inconsistency:** the Hosted KYC guide shows the response field as `url`; the API reference defines `redirect_uri` (used here).

### Step 2 (Alternative): Get Verification Token

To embed the SumSub Web/Mobile SDK in your own UI:

```
POST /api/v1/user/verification-token
Authorization: Bearer {user_token}
X-Chain-Id: {chainId}
Content-Type: application/json
```

**Response:**

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

Use this token to initialize the SumSub SDK (see the SumSub SDK documentation).

With an S2S token, user identity headers apply: exactly one of `X-User-Wallet` (the EOA, not the Smart Wallet), `X-User-Email`, `X-User-Id`.

### Step 3: Wait for the result

User completes KYC -> SumSub sends the result to Wirex -> Wirex sends a webhook with the updated verification status (`/v2/webhooks/user`, or legacy `/webhook/users`) and activates the account. Restricted operations (card issuance, fiat withdrawals) stay unavailable until KYC is approved.

The phone number the user enters in the SumSub form is stored on the profile and **automatically marked as confirmed**.

### Code Example (JavaScript)

```javascript
const API_BASE = 'https://api-baas.wirexapp.com';

// Step 1: Register
const registerResponse = await fetch(`${API_BASE}/api/v2/user`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${partnerToken}`,
    'X-Chain-Id': chainId.toString(),
  },
  body: JSON.stringify({
    user_address: '0xAbC123...EOA',
    initial_data: {
      profile: { email: 'user@example.com' },
      residence_address: { country: 'GB' },
    },
  }),
});
const { id: userId } = await registerResponse.json();

// Step 2: Get verification link (S2S token + user identity header)
const linkResponse = await fetch(`${API_BASE}/api/v1/user/verification-link`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${partnerToken}`,
    'X-User-Wallet': userEoaAddress,
    'X-Chain-Id': chainId.toString(),
  },
  body: JSON.stringify({}),
});
const { redirect_uri } = await linkResponse.json();
console.log(`Redirect user to: ${redirect_uri}`);
```

---

## Flow 2: SumSub Shared KYC

For partners whose users are already verified via SumSub. The partner shares the existing verification with Wirex via a `sharing_token`.

> **Approval required:** only available after a detailed Wirex audit (3-sided data sharing agreement with Wirex and SumSub); may be rejected. Contact your Wirex account manager.

### Prerequisites

- SumSub integration able to generate share tokens for external clients.
- Target client ID for Wirex: **`wirexapp.com_51921`**.
- The SumSub applicant must carry all data Wirex needs; otherwise verification stays incomplete until the user uploads the missing data/documents manually.

**Applicant data (required unless noted):** first name, last name, date of birth, nationality, phone, country, city, street, building number, postcode; state and street line 2 are optional.

**Documents:** selfie (liveness check, required); Proof of Identity (required; ask your Wirex account manager for accepted document types per country; must have more than 1 month of validity left); Proof of Address (required; issued within the last 6 months). User age: 18-90.

**Questionnaire:** the applicant must have a completed SumSub questionnaire (planned use of the app, employment status and industry, yearly income, estimated monthly card spend, PEP declaration). Get the definition from your Wirex account manager, add it to your SumSub verification level, and keep section IDs, item IDs and option values unchanged -- Wirex reads answers by value.

### Step 1: Generate a Share Token

Use SumSub's "Generate Share Token" API (https://docs.sumsub.com/reference/generate-share-token) with the target client ID `wirexapp.com_51921`, once the user is verified in your SumSub flow.

### Step 2: Register User with Sharing Token

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "user_address": "0xAbC123...EOA",
  "sharing_data": {
    "sharing_token": "eyJhbGciOi...",
    "email": "user@example.com"
  }
}
```

> **IMPORTANT:** `sharing_data` and `initial_data` are mutually exclusive — do not provide both.

Wirex fetches the verification from SumSub, validates it and creates the account. The phone number from SumSub verification is **automatically confirmed**.

### Code Example (JavaScript)

```javascript
const API_BASE = 'https://api-baas.wirexapp.com';

const registerResponse = await fetch(`${API_BASE}/api/v2/user`, {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    Authorization: `Bearer ${partnerToken}`,
    'X-Chain-Id': chainId.toString(),
  },
  body: JSON.stringify({
    user_address: '0xAbC123...EOA',
    sharing_data: { sharing_token: sharingToken, email: 'user@example.com' },
  }),
});
const { id } = await registerResponse.json();
console.log(`User registered with shared KYC: ${id}`);
```

### Share Token Errors

| Error | Cause | Resolution |
|-------|-------|------------|
| Invalid sharing token | Token expired or malformed | Generate a new token |
| Share token rejected | Target client ID mismatch | Generate for `wirexapp.com_51921` |
| Verification not found | User not verified in SumSub | Complete user verification first |
| Agreement not active | Data sharing agreement missing | Contact Wirex account manager |

---

## Flow 3: KYC Sharing via API

The partner performs full KYC on its own platform and submits the verified data and documents via API.

> **Approval required:** only available under the Enterprise model, subject to a detailed Wirex audit; may be rejected.

You are responsible for performing identity verification to regulatory standards, maintaining verification records and audit trails, ensuring data accuracy and currency, and complying with applicable KYC/AML regulations.

### Step 1: Register User with Full Profile

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "user_address": "0xAbC123...EOA",
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
      "line2": "Flat 2",
      "city": "London",
      "post_code": "SW1A 2AA",
      "country": "GB"
    }
  }
}
```

The phone number provided here is **automatically confirmed**. The reference schema additionally lists `initial_data.is_pep` (boolean) as required.

### Step 2: Upload Documents

All documents must be uploaded before the account can be fully activated.

```
POST /api/v1/user/documents
Content-Type: multipart/form-data
Authorization: Bearer {user_token}
X-Chain-Id: {chainId}
```

Fields (all four are required in the API reference):

| Field | Values | Description |
|-------|--------|-------------|
| `document` | File | The document file |
| `document_type` | `identity_card`, `passport`, `driver_license`, `proof_of_address`, `other` | Document classification |
| `document_country` | ISO 3166-1 alpha-2 | Issuing country of the document |
| `side` | `front`, `back`, `none` | Which side of the document |

The KYC Sharing guide lists the required documents as selfie, proof of identity (passport / national ID / driver's license) and proof of address (utility bill / bank statement).

> **Docs inconsistency:** the guide names the types `selfie`, `poi`, `poa`, and its error table lists `selfie` as a valid `document_type`; the API reference enum has no `selfie`, `poi` or `poa` (values above are from the reference).

```javascript
const FormData = require('form-data');
const fs = require('fs');
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';

async function uploadDocument(userToken, documentType, filePath, country, side = 'front') {
  const form = new FormData();
  form.append('document_type', documentType);
  form.append('document_country', country);
  form.append('side', side);
  form.append('document', fs.createReadStream(filePath));

  const response = await axios.post(`${API_BASE}/api/v1/user/documents`, form, {
    headers: { ...form.getHeaders(), Authorization: `Bearer ${userToken}` },
  });
  return response.data; // empty object on success
}

await uploadDocument(userToken, 'passport', './passport.jpg', 'GB', 'front');
await uploadDocument(userToken, 'proof_of_address', './utility_bill.pdf', 'GB', 'none');
```

### Correcting KYC Data

```
PUT /api/v2/user/kyc-data
```

Updates profile (`first_name`, `last_name`, `date_of_birth`, `nationality`, `phone_number`), `residence_address` and `is_pep` already on file -- to fix mistyped data before verification completes, not to re-verify. At least one of `profile` or `residence_address` is required (sending only `is_pep` is refused); every field is individually optional. Response `{}`. **Not available under the Wirex Hosted model** (corrections go through the hosted flow).

---

## Field Validation Patterns

Enforced patterns are listed in the Field Validation Rules page and published at runtime via `GET /api/v1/validation/rules` (published rules are not identical to enforced ones; the enforced pattern decides).

### Registration Fields

| Field | Type | Required | Validation | Example |
|-------|------|----------|------------|---------|
| `user_address` | string | Yes | `^0x[a-fA-F0-9]{40}$` (EVM) — must be EOA, NOT Smart Wallet | `"0xAbC123...def"` |
| `initial_data.profile.email` | string | Yes | Valid email, unique | `"user@example.com"` |
| `initial_data.residence_address.country` | string | Yes | ISO 3166-1 alpha-2 (`^[A-Z]{2}$`) | `"GB"` |
| `initial_data.profile.first_name` | string | API flow only | `^[a-zA-Z][a-zA-Z\-' ]{1,50}$` (unaccented Latin only) | `"Jane"` |
| `initial_data.profile.last_name` | string | API flow only | `^[a-zA-Z][a-zA-Z\-' ]{1,50}$` | `"Doe"` |
| `initial_data.profile.date_of_birth` | string | API flow only | `YYYY-MM-DD` | `"1990-01-15"` |
| `initial_data.profile.nationality` | string | API flow only | ISO 3166-1 alpha-2 | `"GB"` |
| `initial_data.profile.phone_number` | string | API flow only | `^\+?\d{1,15}$` (E.164, e.g. `+447700900123`) | `"+447700900123"` |
| `sharing_data.sharing_token` | string | SumSub only | Valid SumSub share token for `wirexapp.com_51921` | `"eyJhbGciOi..."` |
| `sharing_data.email` | string | SumSub only | Valid email, unique | `"user@example.com"` |

### Address Fields (inside `initial_data.residence_address`)

| Field | Type | Required | Validation | Example |
|-------|------|----------|------------|---------|
| `line1` | string | Yes (API flow) | `^[A-Za-z0-9&.,''\-/() :+#]{2,100}$` | `"10 Downing Street"` |
| `line2` | string | No | Same as line1 | `"Flat 2"` |
| `city` | string | Yes (API flow) | `^[A-Za-z\s\-'.]{2,100}$` (no digits) | `"London"` |
| `state` | string | No | `^[A-Za-z][A-Za-z\s\-']{1,99}$` | `"England"` |
| `post_code` | string | Yes (API flow) | `^[A-Za-z0-9\s\-]{3,12}$` | `"SW1A 2AA"` |
| `country` | string | Yes | ISO 3166-1 alpha-2 | `"GB"` |

### Common Validation Errors

| Error Reason | Field | Description |
|-------------|-------|-------------|
| `ErrorInvalidField` | `user_address` | Invalid format (must be `^0x[a-fA-F0-9]{40}$` for EVM) |
| `ErrorInvalidField` | `email` | Invalid email format |
| `ErrorInvalidField` | `country` | Invalid ISO 3166-1 alpha-2 code |
| `ErrorInvalidField` | `sharing_token` | Invalid or expired SumSub sharing token |
| `ErrorNotFound` | wallet | Wallet not registered in Accounts contract — complete on-chain registration first |
| `ErrorAlreadyExists` | `email` | A user with this email already exists |
| `ErrorAlreadyExists` | wallet address | A user with this wallet already exists |

Providing both `sharing_data` and `initial_data` fails validation (mutually exclusive).

---

## Phone Confirmation

In all three flows the phone number is **automatically marked as confirmed** (from the SumSub form, the SumSub applicant, or the `phone_number` you submit); the guides state no separate confirmation step is required. A confirmed phone is used for **3DS Authentication** (OTP codes via SMS) and **Read Card Details** (OTP-based verification).

If you need to set or change the number manually, the endpoints below exist. All require `Authorization` plus the usual user identity (`X-User-Wallet: {userEoaAddress}`, `X-Chain-Id: {chainId}` when using an S2S token), and `Content-Type: application/json`.

### Step 1: Set Phone Number

```
PUT /api/v1/user/phone-number
```

```json
{ "phone_number": "+447700900123" }
```

Pattern `^\+?\d{1,15}$` (the `+` is optional per the enforced pattern; the reference example is `61412345678`). Response: `{}`.

### Step 2: Request SMS Code

```
POST /api/v1/confirmation/sms
```

```json
{ "action_type": "VerifyPhone" }
```

`action_type` enum: `GetCardDetails`, `3dsChallenge`, `VerifyPhone`. The SMS goes to the phone number provided during KYC.

**Response:**

```json
{
  "session_id": "00000000-0000-0000-0000-000000000001",
  "code_length": 6,
  "expires_at": "2021-01-01T00:00:00Z",
  "resend_at": "2021-01-01T00:00:00Z",
  "attempts_left": 3
}
```

### Step 3: Verify SMS Code

```
POST /api/v1/confirmation/sms/verify
```

```json
{ "session_id": "00000000-0000-0000-0000-000000000001", "code": "123456" }
```

**Response:** `{ "token": "<action token JWT>" }`

### Step 4: Confirm Phone Number

```
PUT /api/v1/user/phone-number/confirm
```

```json
{ "action_token": "<action token from step 3>" }
```

Response: `{}`.

---

## Verification Statuses

`verification.status` enum (API reference): `None`, `Pending`, `Approved`, `Rejected`, `Canceled`, `Applied`, `InReview`.

| Status | Description |
|--------|-------------|
| `None` | No verification submitted |
| `Applied` | User has unfinished steps in the SumSub SDK, or incomplete data was provided during Shared / KYC-sharing-via-API flows |
| `Pending` | Verification checks being executed on Wirex side |
| `InReview` | Verification checks being executed on Wirex side |
| `Approved` | Verification approved — user is ready to use all features |
| `Canceled` | Verification was rejected — contact Wirex support |
| `Rejected` | Verification was rejected — contact Wirex support |

> **Docs inconsistency:** the KYC overview page lists `NotStarted`, `Applied`, `InReview`, `Approved`, `Rejected`; the User Information page spells the cancelled status `Cancelled`. The API reference enum above (`None`, `Canceled`, …) is used. The docs do not publish a status transition diagram.

---

## Error Handling

All errors follow the standard format:

```json
{
  "error_reason": "ErrorInvalidField",
  "error_description": "Invalid format for email",
  "error_category": {
    "category": "CategoryValidationFailure",
    "http_status_code": 400
  },
  "error_details": [
    { "key": "field", "details": "email" },
    { "key": "issue", "details": "invalid_format" }
  ]
}
```

### Registration Errors

| HTTP | Error Reason | Description |
|------|-------------|-------------|
| 400 | `ErrorInvalidField` | Field format invalid (user_address, email, country, etc.) |
| 400 | `ErrorMissingField` | Required field missing |
| 400 | `ErrorNotFound` | Wallet not registered in Accounts contract |
| 400 | `ErrorAlreadyExists` | Email or wallet address already registered |
