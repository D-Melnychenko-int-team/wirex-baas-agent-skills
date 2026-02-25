---
name: wirex-baas-transfers
description: "Wirex BaaS money transfers — send money to bank accounts and cards. Covers SEPA transfers (EUR, 28 European countries), ACH transfers (USD, 34+ countries), Push-to-Card payouts (PCI tokenization, OCT rails), and recipient management (6 types: Card, SEPA, ACH, Crypto, FasterPayment, SWIFT). All transfers follow the estimate-then-execute pattern."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS Money Transfers

This skill covers all money transfer capabilities in the Wirex Banking-as-a-Service platform: SEPA transfers (EUR), ACH transfers (USD), Push-to-Card via Visa/Mastercard OCT rails, and recipient management.

## Core Pattern: Estimate then Execute

All transfer types in Wirex BaaS follow the **estimate-then-execute** pattern:

1. **Estimate**: Submit transfer details to get a cost estimate. The response includes an `id` (estimation ID) and `expires_at` timestamp.
2. **Execute**: Submit the transfer using the `estimation_id` from step 1 (or specify the `amount` directly). The estimation locks in exchange rates and fees.

This two-step process ensures the user sees exact costs before committing to the transfer.

## SEPA Transfers (EUR)

SEPA (Single Euro Payments Area) enables EUR bank transfers across 28 European countries.

### Prerequisites

- Account must have the **SepaAccount** capability enabled.
- For third-party transfers: **SepaOut3rdParty** capability.
- For first-party transfers: **SepaOut1stParty** capability.

### Flow

1. **Check capability**: Verify the account has `SepaAccount` (status `Active`) in its capabilities list. SEPA bank accounts are **auto-provisioned** upon user verification — no activation call needed.
2. **Retrieve bank details**: Get the IBAN and BIC for the account.
   ```
   GET /api/v1/bank/accounts
   ```
3. **Estimate transfer**: Calculate fees and exchange rates.
   ```
   POST /api/v2/bank/transfer/estimate
   ```
4. **Execute transfer**: Send the payment.
   ```
   POST /api/v1/bank/transfer
   ```

See [references/BANKING.md](references/BANKING.md) for full request/response formats.

## ACH Transfers (USD)

> **WARNING:** ACH recipients require a `legal_address` field; SEPA does not.

ACH (Automated Clearing House) enables USD bank transfers across 34+ countries.

### Prerequisites

- Account must have the **AchAccount** capability enabled.
- For third-party transfers: **AchOut3rdParty** capability.
- For first-party transfers: **AchOut1stParty** capability.

### Flow

1. **Check capability**: Verify the account has `AchAccount` in its capabilities list.
2. **Activate ACH bank details**: Create ACH bank account credentials for the user.
   ```
   POST /api/v1/bank/accounts
   Body: { "account_type": "Ach" }
   ```
3. **Retrieve bank details**: Get the account number and routing number.
   ```
   GET /api/v1/bank/accounts
   ```
4. **Estimate transfer**: Calculate fees and exchange rates.
   ```
   POST /api/v2/bank/transfer/estimate
   ```
5. **Execute transfer**: Send the payment.
   ```
   POST /api/v1/bank/transfer
   ```

See [references/BANKING.md](references/BANKING.md) for full request/response formats.

## Push-to-Card Transfers

Push-to-Card allows sending funds directly to a Visa or Mastercard debit card via OCT (Original Credit Transaction) rails.

### Prerequisites

- Account must have the **CardTransfer** capability enabled.

### Flow

1. **Tokenize card**: Submit the card details to the PCI-compliant endpoint to receive a token. **Requires user-scoped token** (not S2S).
   ```
   POST {pci_url}/b2b/cards/oct?user_id={user_id}
   Body: { card_number, cardholder_name, card_label, is_saved, is_third_party }
   ```
   The `user_id` is obtained from `GET /api/v2/user` response.
2. **Create recipient**: Register the card as a recipient.
   ```
   POST /api/v2/recipients
   Body: { type: "Card", card: { card_id: token, card_pan_last } }
   ```
3. **Estimate transfer**: Calculate fees and amounts.
   ```
   POST /api/v1/cards/transfer/estimate
   ```
4. **Execute transfer**: Send the payment.
   ```
   POST /api/v1/cards/transfer
   ```

**Card validations**: Luhn check, Visa/Mastercard only, expiration date verification.

See [references/PUSH-TO-CARD.md](references/PUSH-TO-CARD.md) for full details including PCI environment URLs.

## Recipients

Wirex BaaS supports 6 recipient types for outgoing transfers:

| Type            | Use Case                            | Key Fields                                |
|-----------------|-------------------------------------|-------------------------------------------|
| Card            | Push-to-Card transfers              | card_id (token), card_pan_last            |
| Sepa            | SEPA EUR bank transfers             | iban, bic                                 |
| Ach             | ACH USD bank transfers              | routing_number, account_number, legal_address |
| Crypto          | Crypto withdrawals                  | address, network                          |
| FasterPayment   | UK Faster Payments (GBP)            | account_number, sort_code                 |
| Swift           | International wire transfers        | iban, bic, legal_address                  |

### Recipient CRUD Operations

| Operation                | Endpoint                                              |
|--------------------------|-------------------------------------------------------|
| List all recipients      | GET /api/v1/recipients                                |
| Get by ID                | GET /api/v1/recipients/{recipient_id}                 |
| Filter by type           | GET /api/v1/recipients/filter/type?type=Card          |
| Create recipient         | POST /api/v2/recipients                               |
| Update personal info     | PUT /api/v1/recipients/{recipient_id}                 |
| Delete recipient         | DELETE /api/v1/recipients/{recipient_id}              |

See [references/RECIPIENTS.md](references/RECIPIENTS.md) for full CRUD reference with all fields and payment type details.

## Activity Steps

All transfers progress through a series of activity steps. The exact steps vary by transfer type.

**SEPA/ACH:** Initiated → CryptoOut → Review → BankOut → Completed

**Push-to-Card:** Initiated → CryptoOut → Review → CardOut → Completed

### Step Descriptions

| Step      | Description                                      |
|-----------|--------------------------------------------------|
| Initiated | Transfer request received and validated          |
| CryptoOut | WUSD/WEUR burned from the user's wallet          |
| Review    | Compliance and risk checks in progress           |
| BankOut   | Funds sent via SEPA/ACH to recipient bank        |
| CardOut   | Funds sent via OCT to recipient card             |
| Completed | Transfer successfully delivered                  |

A transfer can also reach `Failed` or `Cancelled` status at any step.

## Required Capabilities Summary

| Transfer Type         | Required Capabilities                   |
|----------------------|----------------------------------------|
| SEPA account setup    | SepaAccount                            |
| SEPA 1st-party send   | SepaOut1stParty                        |
| SEPA 3rd-party send   | SepaOut3rdParty                        |
| ACH account setup     | AchAccount                             |
| ACH 1st-party send    | AchOut1stParty                         |
| ACH 3rd-party send    | AchOut3rdParty                         |
| Push-to-Card          | CardTransfer                           |

## Webhooks

Transfer activity is reported via webhooks:

| Webhook Endpoint         | Purpose                              |
|--------------------------|--------------------------------------|
| /v2/webhooks/activities  | Transfer activity step updates       |
| /v2/webhooks/recipients  | Recipient creation/update events     |

See individual reference files for webhook payload examples.
