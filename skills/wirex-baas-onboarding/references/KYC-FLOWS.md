# KYC Flows Reference

## Flow 1: Wirex Hosted KYC

The simplest integration. The partner registers the user with minimal data, then redirects them to a Wirex-hosted verification page.

### Step 1: Register User

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "wallet_address": "0xAbC123...EOA",
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

### Step 2: Get Verification Link

```
GET /api/v1/user/verification-link
Authorization: Bearer {user_token}
```

**Response:**

```json
{
  "url": "https://verify.wirexpay.com/kyc?token=eyJhbGciOi..."
}
```

Redirect the user to this URL in a browser or webview. Wirex handles the entire identity collection, document upload, and liveness check.

### Step 3 (Alternative): Get Verification Token

If you prefer to embed the SumSub WebSDK in your own UI rather than redirecting:

```
GET /api/v1/user/verification-token
Authorization: Bearer {user_token}
```

**Response:**

```json
{
  "token": "sbx:abcdef123456..."
}
```

Use this token to initialize the SumSub WebSDK component.

### Code Examples

#### JavaScript

```javascript
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';

// Step 1: Register
const registerResponse = await axios.post(
  `${API_BASE}/api/v2/user`,
  {
    wallet_address: '0xAbC123...EOA',
    initial_data: {
      profile: { email: 'user@example.com' },
      residence_address: { country: 'GB' },
    },
  },
  {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${partnerToken}`,
      'X-Chain-Id': chainId.toString(),
    },
  }
);

const userId = registerResponse.data.id;
console.log(`User registered: ${userId}`);

// Step 2: Get verification link
const linkResponse = await axios.get(
  `${API_BASE}/api/v1/user/verification-link`,
  {
    headers: {
      Authorization: `Bearer ${userToken}`,
    },
  }
);

const verificationUrl = linkResponse.data.url;
console.log(`Redirect user to: ${verificationUrl}`);
```

---

## Flow 2: SumSub Shared KYC

For partners who already use SumSub for their own KYC. The partner completes KYC in their own app using SumSub, then shares the verification result with Wirex via a `sharing_token`.

### Prerequisites

- Active SumSub account with KYC flow configured.
- Target client ID for Wirex: **`wirexapp.com_51921`**
- SumSub sharing token obtained after the user completes KYC in the partner's SumSub flow.

### Step 1: Complete KYC in Partner App

Use the SumSub SDK in your app to collect and verify the user's identity. After successful verification, generate a sharing token targeting Wirex.

### Step 2: Get Sharing Token from SumSub

```
POST https://api.sumsub.com/resources/accessTokens/-/shareToken
Content-Type: application/json

{
  "applicantId": "sumsub_applicant_id",
  "clientId": "wirexapp.com_51921"
}
```

**Response:**

```json
{
  "token": "shr_abc123xyz..."
}
```

### Step 3: Register User with Sharing Token

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "wallet_address": "0xAbC123...EOA",
  "sharing_data": {
    "sharing_token": "shr_abc123xyz...",
    "email": "user@example.com"
  }
}
```

> **IMPORTANT:** `sharing_data` and `initial_data` are mutually exclusive — do not provide both.

Wirex will use the sharing token to pull the verified identity data from SumSub. No additional KYC steps are needed. The phone number from SumSub verification is **automatically confirmed**.

### Code Example (JavaScript)

```javascript
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';
const SUMSUB_API = 'https://api.sumsub.com';

// Step 1: Get sharing token from SumSub (after user completes KYC)
const sharingResponse = await axios.post(
  `${SUMSUB_API}/resources/accessTokens/-/shareToken`,
  {
    applicantId: 'sumsub_applicant_id',
    clientId: 'wirexapp.com_51921',
  },
  {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${sumsubToken}`,
    },
  }
);

const sharingToken = sharingResponse.data.token;

// Step 2: Register with Wirex using sharing token
const registerResponse = await axios.post(
  `${API_BASE}/api/v2/user`,
  {
    wallet_address: '0xAbC123...EOA',
    sharing_data: {
      sharing_token: sharingToken,
      email: 'user@example.com',
    },
  },
  {
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${partnerToken}`,
      'X-Chain-Id': chainId.toString(),
    },
  }
);

console.log(`User registered with shared KYC: ${registerResponse.data.id}`);
console.log(`Verification status: ${registerResponse.data.verification.status}`);
```

---

## Flow 3: API Reliance KYC

Full white-label KYC where the partner collects all identity data, documents, and submits them via API. Highest complexity but maximum control over the user experience.

### Step 1: Register User with Full Profile

> Reliance onboarding requires prior Wirex approval after a detailed audit.

```
POST /api/v2/user
Content-Type: application/json
Authorization: Bearer {partner_token}
X-Chain-Id: {chainId}
```

```json
{
  "wallet_address": "0xAbC123...EOA",
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
      "state": "England",
      "post_code": "SW1A 2AA",
      "country": "GB"
    }
  }
}
```

Phone number (E.164 with `+` prefix) provided during reliance onboarding is **automatically confirmed**.

### Step 2: Upload Documents

```
POST /api/v1/user/documents
Content-Type: multipart/form-data
Authorization: Bearer {user_token}
```

Upload documents using multipart/form-data with these fields:

| Field | Values | Description |
|-------|--------|-------------|
| `document` | File | The document file (required) |
| `document_type` | `selfie`, `identity_card`, `passport`, `driver_license`, `proof_of_address`, `other` | Document classification |
| `document_country` | ISO 3166-1 alpha-2 | Issuing country of the document |
| `side` | `front`, `back`, `none` | Which side of the document |

Required documents: selfie, proof of identity (passport/ID card/driver's license), proof of address (utility bill/bank statement, < 3 months old). Accepted formats: JPEG, PNG, PDF.

#### JavaScript Example

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

  const response = await axios.post(
    `${API_BASE}/api/v1/user/documents`,
    form,
    {
      headers: {
        ...form.getHeaders(),
        Authorization: `Bearer ${userToken}`,
      },
    }
  );

  return response.data;
}

// Upload all three documents
await uploadDocument(userToken, 'selfie', './selfie.jpg', 'GB', 'none');
await uploadDocument(userToken, 'passport', './passport.jpg', 'GB', 'front');
await uploadDocument(userToken, 'proof_of_address', './utility_bill.pdf', 'GB', 'none');

console.log('All documents uploaded.');
```

---

## Field Validation Patterns

### Registration Fields

| Field | Type | Required | Validation | Example |
|-------|------|----------|------------|---------|
| `wallet_address` | string | Yes | `^0x[a-fA-F0-9]{40}$` — must be EOA, NOT Smart Wallet | `"0xAbC123...def"` |
| `initial_data.profile.email` | string | Yes | Valid email, unique | `"user@example.com"` |
| `initial_data.residence_address.country` | string | Yes | ISO 3166-1 alpha-2 | `"GB"`, `"US"`, `"DE"` |
| `initial_data.profile.first_name` | string | Reliance only | `^[a-zA-Z][a-zA-Z\-' ]{1,50}$` | `"Jane"` |
| `initial_data.profile.last_name` | string | Reliance only | `^[a-zA-Z][a-zA-Z\-' ]{1,50}$` | `"Doe"` |
| `initial_data.profile.date_of_birth` | string | Reliance only | `YYYY-MM-DD`, user must be 18+ | `"1990-01-15"` |
| `initial_data.profile.nationality` | string | Reliance only | ISO 3166-1 alpha-2 | `"GB"` |
| `initial_data.profile.phone_number` | string | Reliance only | E.164 format (e.g., `+447700900123`) | `"+447700900123"` |
| `sharing_data.sharing_token` | string | SumSub only | Valid SumSub share token for `wirexapp.com_51921` | `"shr_abc123xyz"` |
| `sharing_data.email` | string | SumSub only | Valid email, unique | `"user@example.com"` |

### Address Fields (inside `initial_data.residence_address`)

| Field | Type | Required | Validation | Example |
|-------|------|----------|------------|---------|
| `line1` | string | Yes (Reliance) | `^[A-Za-z0-9&.,''\-/() :+#]{2,100}$` | `"10 Downing Street"` |
| `line2` | string | No | Same as line1 | `"Flat 2"` |
| `city` | string | Yes (Reliance) | `^[A-Za-z\s\-'.]{2,100}$` | `"London"` |
| `state` | string | No | `^[A-Za-z][A-Za-z\s\-']{1,99}$` | `"England"` |
| `post_code` | string | Yes (Reliance) | `^[A-Za-z0-9\s\-]{3,12}$` | `"SW1A 2AA"` |
| `country` | string | Yes (Reliance) | ISO 3166-1 alpha-2 | `"GB"` |

### Common Validation Errors

| Error Reason | Field | Description |
|-------------|-------|-------------|
| `ErrorInvalidField` | `wallet_address` | Invalid format (must be `^0x[a-fA-F0-9]{40}$`) |
| `ErrorInvalidField` | `email` | Invalid email format |
| `ErrorInvalidField` | `country` | Invalid ISO 3166-1 alpha-2 code |
| `ErrorInvalidField` | `sharing_token` | Invalid or expired SumSub sharing token |
| `ErrorNotFound` | `wallet_address` | Wallet not registered in Accounts contract — complete on-chain registration first |
| `ErrorAlreadyExists` | `email` | A user with this email already exists |
| `ErrorAlreadyExists` | `wallet_address` | A user with this wallet already exists |

---

## Phone Confirmation Flow

Phone confirmation is required for **Wirex Hosted KYC** (the hosted flow does not collect phone — it must be set separately). For SumSub Shared and Reliance flows, the phone is **automatically confirmed** from the verification data.

Confirmed phone is required for: **3DS Authentication** (OTP codes for card transactions) and **Read Card Details** (OTP-based PAN/CVV/PIN retrieval).

All phone confirmation endpoints require headers: `Authorization: Bearer {token}`, `X-User-Address: {userEoaAddress}`, `X-Chain-Id: {chainId}`, `Content-Type: application/json`.

### Step 1: Set Phone Number

```
PUT /api/v1/user/phone-number
```

```json
{
  "phone_number": "+447700900123"
}
```

> **Note:** Provide the phone number in E.164 format with the `+` prefix (e.g., `+447700900123`).

### Step 2: Request SMS Code

```
POST /api/v1/confirmation/sms
```

```json
{
  "action_type": "VerifyPhone"
}
```

**Response:**

```json
{
  "session_id": "uuid-session-id",
  "code_length": 6,
  "expires_at": "2025-01-15T10:05:00Z"
}
```

### Step 3: Verify SMS Code

```
POST /api/v1/confirmation/sms/verify
```

```json
{
  "session_id": "uuid-session-id",
  "code": "123456"
}
```

**Response:**

```json
{
  "token": "action-token-string"
}
```

### Step 4: Confirm Phone Number

```
PUT /api/v1/user/phone-number/confirm
```

```json
{
  "action_token": "action-token-string"
}
```

### Phone Confirmation Code Example (JavaScript)

```javascript
const axios = require('axios');

const API_BASE = 'https://api-baas.wirexapp.com';

async function confirmPhoneNumber(userToken, phoneNumber, userEoaAddress, chainId, smsCode) {
  const headers = {
    Authorization: `Bearer ${userToken}`,
    'X-User-Address': userEoaAddress,
    'X-Chain-Id': chainId.toString(),
    'Content-Type': 'application/json',
  };

  // Step 1: Set phone number (without leading +)
  await axios.put(
    `${API_BASE}/api/v1/user/phone-number`,
    { phone_number: phoneNumber },
    { headers }
  );

  // Step 2: Request SMS code
  const smsResponse = await axios.post(
    `${API_BASE}/api/v1/confirmation/sms`,
    { action_type: 'VerifyPhone' },
    { headers }
  );

  const sessionId = smsResponse.data.session_id;

  // Step 3: Verify SMS code (code provided by user)
  const verifyResponse = await axios.post(
    `${API_BASE}/api/v1/confirmation/sms/verify`,
    { session_id: sessionId, code: smsCode },
    { headers }
  );

  const actionToken = verifyResponse.data.token;

  // Step 4: Confirm phone number
  await axios.put(
    `${API_BASE}/api/v1/user/phone-number/confirm`,
    { action_token: actionToken },
    { headers }
  );

  console.log('Phone confirmed.');
}
```

---

## Verification Status Transitions

**Main path:** None → Applied → InReview → Approved

**Alternate paths:** Applied → Pending (info requested) → Applied (info provided); InReview → Rejected; Applied → Canceled

| Transition | Trigger |
|-----------|---------|
| `None` -> `Applied` | User submits KYC (any flow) |
| `Applied` -> `InReview` | Automated checks pass, moved to review queue |
| `Applied` -> `Pending` | Additional information requested |
| `Pending` -> `Applied` | User provides additional information |
| `InReview` -> `Approved` | Reviewer approves the application |
| `InReview` -> `Rejected` | Reviewer rejects the application |
| `Applied` -> `Canceled` | User or partner cancels the application |

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
| 400 | `ErrorInvalidField` | Field format invalid (wallet_address, email, country, etc.) |
| 400 | `ErrorMissingField` | Required field missing |
| 400 | `ErrorNotFound` | Wallet not registered in Accounts contract |
| 400 | `ErrorAlreadyExists` | Email or wallet address already registered |
| 401 | `ErrorPermissionDenied` | Invalid or expired token |
