# User Profile and Capabilities Reference

## User Profile Endpoint

```
GET /api/v2/user
Authorization: Bearer {token}
X-User-Address: {userEoaAddress}
X-Chain-Id: {chainId}
```

### Complete Response Schema

```json
{
  "id": "usr_abc123",
  "owner": "0xAbC123...EOA",
  "chain_id": 8453,
  "profile": {
    "status": "Active",
    "email": "user@example.com",
    "first_name": "Jane",
    "last_name": "Doe",
    "date_of_birth": "1990-01-15",
    "nationality": "GB",
    "phone_number": "+447700900123",
    "phone_confirmed": true,
    "created_at": "2025-01-10T14:30:00Z",
    "updated_at": "2025-01-12T09:00:00Z"
  },
  "residence_address": {
    "line1": "10 Downing Street",
    "line2": "Flat 2",
    "city": "London",
    "state": "England",
    "post_code": "SW1A 2AA",
    "country": "GB"
  },
  "verification": {
    "status": "Approved",
    "levels": [
      { "type": "SDD", "order": 1 }
    ],
    "documents": []
  },
  "external_providers": {
    "sumsub": {
      "applicant_id": "sb_applicant_123",
      "status": "completed"
    }
  },
  "capabilities": [
    {
      "type": "VisaVirtualCard",
      "status": "Active",
      "status_reason": null,
      "verification_requirements": [],
      "prerequisites": []
    },
    {
      "type": "SepaAccount",
      "status": "Active",
      "status_reason": null,
      "verification_requirements": [],
      "prerequisites": []
    },
    {
      "type": "VisaPlasticCard",
      "status": "InProgress",
      "status_reason": "address_verification_pending",
      "verification_requirements": ["poa"],
      "prerequisites": ["VisaVirtualCard"]
    }
  ]
}
```

---

## Profile Statuses

| Status | Meaning | Description |
|--------|---------|-------------|
| `Active` | Fully operational | User account is active and can use all granted capabilities |
| `Pending` | Awaiting setup | User registered but onboarding is incomplete (e.g., KYC not started) |
| `Blocked` | Temporarily suspended | Account has been blocked due to compliance review or suspicious activity |
| `Deleted` | Permanently closed | Account has been permanently deleted; cannot be reactivated |

### Status Transitions

**Normal path:** Pending → Active ↔ Blocked → Active (unblocked)

**Terminal:** Active → Deleted; Blocked → Deleted

---

## Verification Levels

Verification levels determine the tier of services available to the user. Higher levels unlock greater transaction limits and additional capabilities.

| Level | Full Name | Description | Typical Limits |
|-------|-----------|-------------|----------------|
| `BDD` | Basic Due Diligence | Minimal verification; limited functionality | Low transaction limits; crypto only |
| `SDD` | Standard Due Diligence | Standard KYC completed; card and banking access | Standard limits; full card and banking |
| `EDD` | Enhanced Due Diligence | Enhanced verification for high-value users | Elevated limits; premium features |

### Level Requirements

| Level | Requirements |
|-------|-------------|
| `BDD` | Email verification + basic profile |
| `SDD` | Government-issued ID + selfie + proof of address |
| `EDD` | SDD + source of funds documentation + enhanced screening |

---

## Capabilities System

Capabilities are the **feature-gating mechanism** in Wirex BaaS. Each capability represents a specific product or service that a user may or may not have access to. The capabilities array on the user profile dynamically reflects the user's current state.

### Capability Object Schema

```json
{
  "type": "VisaVirtualCard",
  "status": "Active",
  "status_reason": null,
  "verification_requirements": [],
  "prerequisites": []
}
```

| Field | Type | Description |
|-------|------|-------------|
| `type` | string | The capability identifier (see tables below) |
| `status` | string | Current status of this capability for the user |
| `status_reason` | string or null | Human-readable reason when status is not `Active` |
| `verification_requirements` | array of strings | Outstanding verification steps needed to activate |
| `prerequisites` | array of strings | Other capabilities that must be `Active` first |

### Capability Statuses

| Status | Meaning | User Action |
|--------|---------|-------------|
| `Active` | Capability is available and usable | None; feature is live |
| `ActivationNotStarted` | Capability exists but user has not begun activation | Start the activation process |
| `InProgress` | Activation has been started but is not yet complete | Complete outstanding requirements |
| `NotFulfilled` | Requirements exist that have not been met | Fulfill `verification_requirements` and `prerequisites` |
| `NotAvailable` | Capability is not available for this user/region | N/A; cannot be activated |

---

## Capability Types

### Card Capabilities

| Capability | Description | Prerequisites | Notes |
|-----------|-------------|---------------|-------|
| `VisaVirtualCard` | Issue Visa virtual cards | KYC Approved (SDD+) | Immediate digital issuance |
| `VisaPlasticCard` | Issue Visa physical (plastic) cards | `VisaVirtualCard` active | Requires delivery address |
| `CardTransfer` | Transfer funds to/from card balance | Any card active | Used for card top-up |

### SEPA Banking Capabilities (Europe)

| Capability | Description | Prerequisites |
|-----------|-------------|---------------|
| `SepaAccount` | SEPA bank account (IBAN) | KYC Approved (SDD+) |
| `SepaIn1stParty` | Receive SEPA transfers from own accounts | `SepaAccount` |
| `SepaOut1stParty` | Send SEPA transfers to own accounts | `SepaAccount` |
| `SepaIn3rdParty` | Receive SEPA transfers from third parties | `SepaAccount` |
| `SepaOut3rdParty` | Send SEPA transfers to third parties | `SepaAccount` |

### ACH Banking Capabilities (United States)

| Capability | Description | Prerequisites |
|-----------|-------------|---------------|
| `AchAccount` | ACH bank account | KYC Approved (SDD+) |
| `AchIn1stParty` | Receive ACH transfers from own accounts | `AchAccount` |
| `AchOut1stParty` | Send ACH transfers to own accounts | `AchAccount` |
| `AchIn3rdParty` | Receive ACH transfers from third parties | `AchAccount` |
| `AchOut3rdParty` | Send ACH transfers to third parties | `AchAccount` |

### Faster Payments Capabilities (United Kingdom)

| Capability | Description | Prerequisites |
|-----------|-------------|---------------|
| `FasterPaymentsAccount` | Faster Payments bank account | KYC Approved (SDD+) |
| `FasterPaymentsIn1stParty` | Receive FPS from own accounts | `FasterPaymentsAccount` |
| `FasterPaymentsOut1stParty` | Send FPS to own accounts | `FasterPaymentsAccount` |
| `FasterPaymentsIn3rdParty` | Receive FPS from third parties | `FasterPaymentsAccount` |
| `FasterPaymentsOut3rdParty` | Send FPS to third parties | `FasterPaymentsAccount` |

### SPEI Capabilities (Mexico)

| Capability | Description | Prerequisites |
|-----------|-------------|---------------|
| `SpeiAccount` | SPEI bank account | KYC Approved (SDD+) |
| `SpeiIn1stParty` | Receive SPEI from own accounts | `SpeiAccount` |
| `SpeiOut1stParty` | Send SPEI to own accounts | `SpeiAccount` |
| `SpeiIn3rdParty` | Receive SPEI from third parties | `SpeiAccount` |
| `SpeiOut3rdParty` | Send SPEI to third parties | `SpeiAccount` |

### Regional Capabilities

| Capability | Region | Description |
|-----------|--------|-------------|
| `PixOut3rdParty` | Brazil | Send Pix transfers to third parties |
| `FpsHkOut3rdParty` | Hong Kong | Send FPS HK transfers to third parties |
| `ImpsOut3rdParty` | India | Send IMPS transfers to third parties |
| `InstapayOut3rdParty` | Philippines | Send InstaPay transfers to third parties |
| `BiFastOut3rdParty` | Indonesia | Send BI-FAST transfers to third parties |
| `NipOut3rdParty` | Nigeria | Send NIP transfers to third parties |
| `IppOut3rdParty` | Thailand | Send IPP transfers to third parties |
| `PseOut3rdParty` | Colombia | Send PSE transfers to third parties |

---

## Feature Gating Code Examples

### JavaScript: Check If User Can Issue Virtual Card

```javascript
async function canIssueVirtualCard(userToken) {
  const response = await fetch('https://api-baas.wirexapp.com/api/v2/user', {
    headers: { Authorization: `Bearer ${userToken}` },
  });
  const user = await response.json();

  const virtualCardCap = user.capabilities.find(
    (cap) => cap.type === 'VisaVirtualCard'
  );

  if (!virtualCardCap) {
    console.log('Virtual card capability not available for this user.');
    return false;
  }

  if (virtualCardCap.status === 'Active') {
    console.log('User can issue virtual cards.');
    return true;
  }

  if (virtualCardCap.status === 'NotFulfilled') {
    console.log(
      `Requirements not met: ${virtualCardCap.verification_requirements.join(', ')}`
    );
    return false;
  }

  console.log(`Capability status: ${virtualCardCap.status}`);
  return false;
}
```

### JavaScript: Build Feature Menu from Capabilities

```javascript
async function buildFeatureMenu(userToken) {
  const response = await fetch('https://api-baas.wirexapp.com/api/v2/user', {
    headers: { Authorization: `Bearer ${userToken}` },
  });
  const user = await response.json();

  const featureMap = {
    VisaVirtualCard: { label: 'Virtual Card', icon: 'credit-card' },
    VisaPlasticCard: { label: 'Physical Card', icon: 'card' },
    SepaAccount: { label: 'EUR Bank Account', icon: 'bank' },
    SepaOut3rdParty: { label: 'Send EUR', icon: 'send' },
    AchAccount: { label: 'USD Bank Account', icon: 'bank' },
    AchOut3rdParty: { label: 'Send USD', icon: 'send' },
    FasterPaymentsAccount: { label: 'GBP Bank Account', icon: 'bank' },
    FasterPaymentsOut3rdParty: { label: 'Send GBP', icon: 'send' },
  };

  const menuItems = [];

  for (const cap of user.capabilities) {
    const feature = featureMap[cap.type];
    if (!feature) continue;

    menuItems.push({
      ...feature,
      type: cap.type,
      enabled: cap.status === 'Active',
      status: cap.status,
      reason: cap.status_reason,
      requirements: cap.verification_requirements,
    });
  }

  return menuItems;
}
```

---

## Profile Response Field Reference

### Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique user identifier |
| `owner` | string | EOA address that owns this account |
| `chain_id` | number | Primary blockchain chain ID (e.g., 8453 for Base) |
| `profile` | object | User profile information |
| `residence_address` | object | User's residential address |
| `verification` | object | KYC verification status and level |
| `external_providers` | object | Connected third-party provider info (e.g., SumSub) |
| `capabilities` | array | List of capability objects |

### Profile Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `profile.status` | string | Account status: `Active`, `Pending`, `Blocked`, `Deleted` |
| `profile.email` | string | Registered email address |
| `profile.first_name` | string | First name (populated after KYC or Reliance registration) |
| `profile.last_name` | string | Last name |
| `profile.date_of_birth` | string | Date of birth (ISO 8601) |
| `profile.nationality` | string | Nationality (ISO 3166-1 alpha-2) |
| `profile.phone_number` | string | Phone number in E.164 format (includes `+` prefix and country code) |
| `profile.phone_confirmed` | boolean | Whether the phone number has been confirmed |
| `profile.created_at` | string | Account creation timestamp (ISO 8601) |
| `profile.updated_at` | string | Last profile update timestamp (ISO 8601) |

### Residence Address Fields

| Field | Type | Description |
|-------|------|-------------|
| `residence_address.line1` | string | Street address line 1 |
| `residence_address.line2` | string | Street address line 2 (optional) |
| `residence_address.city` | string | City |
| `residence_address.state` | string | State or province |
| `residence_address.post_code` | string | Postal / ZIP code |
| `residence_address.country` | string | Country (ISO 3166-1 alpha-2) |

### Verification Object Fields

| Field | Type | Description |
|-------|------|-------------|
| `verification.status` | string | KYC status: `None`, `Applied`, `Pending`, `InReview`, `Approved`, `Canceled`, `Rejected` |
| `verification.levels` | array | Array of verification level objects, each with `type` (e.g., `"SDD"`) and `order` |
| `verification.documents` | array | Array of submitted document objects with `type`, `id`, `file_type`, `added_date` |

### External Providers Object

| Field | Type | Description |
|-------|------|-------------|
| `external_providers.sumsub.applicant_id` | string | SumSub applicant identifier |
| `external_providers.sumsub.status` | string | SumSub verification status |

---

## Common Patterns

### Poll for Verification Approval

```javascript
async function waitForApproval(userToken, maxAttempts = 60, intervalMs = 5000) {
  for (let i = 0; i < maxAttempts; i++) {
    const response = await fetch('https://api-baas.wirexapp.com/api/v2/user', {
      headers: { Authorization: `Bearer ${userToken}` },
    });
    const user = await response.json();

    const status = user.verification.status;
    console.log(`Attempt ${i + 1}: Verification status = ${status}`);

    if (status === 'Approved') {
      console.log(`Verified at level: ${user.verification.level}`);
      return user;
    }

    if (status === 'Rejected' || status === 'Canceled') {
      throw new Error(`Verification ${status}`);
    }

    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }

  throw new Error('Verification polling timed out');
}
```

### Check All Requirements Before Action

```javascript
function canPerformAction(user, requiredCapability) {
  // Check profile is active
  if (user.profile.status !== 'Active') {
    return {
      allowed: false,
      reason: `Account is ${user.profile.status}`,
    };
  }

  // Check KYC is approved
  if (user.verification.status !== 'Approved') {
    return {
      allowed: false,
      reason: `KYC status is ${user.verification.status}`,
    };
  }

  // Check capability
  const cap = user.capabilities.find((c) => c.type === requiredCapability);

  if (!cap) {
    return {
      allowed: false,
      reason: `Capability ${requiredCapability} not found`,
    };
  }

  if (cap.status !== 'Active') {
    return {
      allowed: false,
      reason: cap.status_reason || `Capability status is ${cap.status}`,
      requirements: cap.verification_requirements,
      prerequisites: cap.prerequisites,
    };
  }

  return { allowed: true };
}
```
