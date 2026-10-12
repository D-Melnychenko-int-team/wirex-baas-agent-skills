---
name: wirex-baas-transfers
description: "Wirex BaaS money transfers — send money to bank accounts and cards. Covers SEPA transfers (EUR, accounts for residents of 29 countries, explicit activation required), ACH transfers (USD, accounts for residents of 48 countries), v3 corridor transfers (16 payout rails), Push-to-Card payouts (PCI tokenization, OCT rails), and recipient management (16 payment-detail types, e.g. Card, Sepa, Ach, Crypto, FasterPayment, Swift). All transfers follow the estimate-then-execute pattern."
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

1. **Estimate**: Submit transfer details to get a cost estimate. The response includes an `id` (estimation ID; `estimation_id` for card transfers) and an `expires_at` Unix timestamp, plus `estimated_amounts[]` (one entry per token, with `amount`, `precise_amount` in the token's smallest unit, `rate` and, where reported, `fee_amount` / `fee_precise_amount`).
2. **Execute**: Submit the transfer using the `estimation_id` from step 1 (bank transfers can alternatively specify `amount` directly, not both) and the `token_address` to charge. The estimation locks in exchange rates and fees.

This two-step process ensures the user sees exact costs before committing to the transfer.

## SEPA Transfers (EUR)

SEPA (Single Euro Payments Area) enables EUR bank transfers. SEPA accounts are available to users residing in 29 countries: AT, BE, BG, CY, CZ, DK, EE, FI, FR, DE, GR, HU, IS, IE, IT, LV, LT, LU, MT, NL, NO, PL, PT, RO, SK, SI, ES, SE, GB (the `SepaAccount` capability is `NotAvailable` elsewhere).

### Prerequisites

- Account must have the **SepaAccount** capability enabled.
- For third-party transfers: **SepaOut3rdParty** capability.
- For first-party transfers: **SepaOut1stParty** capability.

### Flow

1. **Check capability**: Read the `SepaAccount` capability from `GET /api/v2/user` and branch on its status. SEPA accounts are **not** auto-provisioned: verification alone does not create an IBAN, activation is required.
2. **Activate the account**:
   - `ActivationNotStarted`: `POST /api/v1/bank/accounts` with `{ "account_type": "Sepa" }` (returns `{ "details_id": ... }`).
   - `ExternalProviderVerificationRequired`: wallet-linking path: `POST /api/v1/bank/accounts/init` (`{ "chain": "8453" }`, numeric chain ID as a string, returns `challenge` + `wallet_address`) → sign the challenge with the user's Primary wallet → `POST /api/v1/bank/accounts/complete` (`{ "chain", "signed_challenge" }`).
   - `ExternalProviderRegistrationPending` or `InProgress`: wait for the `/webhook/accounts/fiat` bank account webhook. `Active`: already provisioned.
   - The two paths are mutually exclusive; calling the wrong one returns `400`.
3. **Retrieve bank details**: Get the IBAN and BIC for the account.
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

## ACH Transfers (USD)

> **WARNING:** ACH recipients require a `legal_address` field; SEPA does not.

ACH (Automated Clearing House) enables USD bank transfers. ACH accounts are available to users residing in 48 countries (see [references/BANKING.md](references/BANKING.md) for the list) and all US states and territories.

### Prerequisites

- Account must have the **AchAccount** capability enabled.
- For third-party transfers: **AchOut3rdParty** capability.
- For first-party transfers: **AchOut1stParty** capability.

### Flow

1. **Check capability**: Verify `AchAccount` in `GET /api/v2/user`; activate when its status is `ActivationNotStarted`.
2. **Activate ACH bank details** (status then becomes `InProgress` until the bank account webhook reports details): Create ACH bank account credentials for the user.
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

**Card validations**: Luhn check, Visa/Mastercard only, not expired. The tokenization response is `{ "value": "tok_..." }`; the recipient's `payment_details[].id` is used as `external_card_id` in the estimate. In browsers, `@wirexapp/card-oct-web` can tokenize inside Wirex iframes instead of calling the PCI endpoint directly.

See [references/PUSH-TO-CARD.md](references/PUSH-TO-CARD.md) for full details including PCI environment URLs.

## Corridor Transfers (v3)

One set of endpoints covers 16 payout rails, with the corridor as a path parameter:

```
POST /api/v3/bank/estimate/{corridor}   body: destination_amount, recipient_id, recipient_payment_details_id, [account_id], [source_tokens]
POST /api/v3/bank/initiate/{corridor}   body: estimation_id, source_token_address, [reference]
POST /api/v3/bank/confirm/{corridor}    body: transfer_id, actions[{type:"FundTransfer", data:{tx_hash}}]
```

Corridors: `sepa`, `ach`, `faster-payments` (provider `service-bank`, `account_id` required, no confirm step); `pix`, `spei`, `fedwire`, `swift`, `cips`, `chats`, `fps_hk` (CPN: confirm step required); `imps`, `instapay`, `bi-fast`, `nip`, `ipp`, `pse` (offramp: no confirm). Branch on `required_actions` in the initiate response, not on the corridor name: when present, send the funds on-chain as described, then confirm. Each corridor needs its own `*Out3rdParty` capability `Active`. SEPA and ACH remain valid via the v2/v1 endpoints above. See [Corridor Transfers](https://docs.wirexapp.com/docs/retail-corridor-transfers) docs for field details.

## Recipients

Wirex BaaS supports 16 payment-detail types for recipients (`type` enum): Crypto, Sepa, FasterPayment, Ach, Swift, Spei, Card, Pix, FpsHk, Imps, Instapay, BiFast, Nip, Ipp, Pse, CrossChainCrypto. The main ones:

| Type            | Use Case                            | Key Fields                                |
|-----------------|-------------------------------------|-------------------------------------------|
| Card            | Push-to-Card transfers              | card_id (token), card_pan_last            |
| Sepa            | SEPA EUR bank transfers             | iban, bic                                 |
| Ach             | ACH USD bank transfers              | routing_number, account_number, legal_address (bank_name optional) |
| Crypto          | Crypto withdrawals                  | recipient_address (replaces `address`), network |
| FasterPayment   | UK Faster Payments (GBP)            | account_number, sort_code                 |
| Swift           | International wire transfers        | iban, bic, bank_country, bank_name, legal_address |

The others (Spei, Pix, FpsHk, Imps, Instapay, BiFast, Nip, Ipp, Pse, CrossChainCrypto) are listed in [references/RECIPIENTS.md](references/RECIPIENTS.md).

### Recipient CRUD Operations

| Operation                | Endpoint                                              |
|--------------------------|-------------------------------------------------------|
| List all recipients      | GET /api/v1/recipients                                |
| Get by ID                | GET /api/v1/recipients/{recipient_id}                 |
| Filter by type           | GET /api/v1/recipients/filter/type?type=Card          |
| Filter by currency/name/catalog | GET /api/v1/recipients/filter/currency, /name, /catalog |
| Record usage (for `sort=usage`) | POST /api/v1/recipients/{recipient_id}/usage    |
| Create recipient         | POST /api/v2/recipients                               |
| Update personal info     | PUT /api/v1/recipients/{recipient_id}                 |
| Update personal info + payment details | PUT /api/v2/recipients/{recipient_id}   |
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

Activity `status` is `Pending`, `Completed` or `Failed` (documented activity statuses; `Cancelled` is not documented). Other step types seen on the activity feed: `BankIn`, `CryptoIn`, `CardIn`, `Reversal`, `SyntheticWrap`, `SyntheticUnwrap`.

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
| Corridor (v3) transfers | `<Corridor>Out3rdParty`, e.g. PixOut3rdParty |

## Webhooks

Transfer activity is reported via webhooks:

| Webhook Endpoint         | Purpose                              |
|--------------------------|--------------------------------------|
| /v2/webhooks/activities  | Transfer activity step updates       |
| /v2/webhooks/recipients  | Recipient creation/update events     |

See individual reference files for webhook payload examples.
