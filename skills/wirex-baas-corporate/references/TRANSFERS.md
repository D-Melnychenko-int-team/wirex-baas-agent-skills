# Wirex BaaS Corporate — Transfers, FX and Bank Accounts

Guides: [Bank Accounts](https://docs.wirexapp.com/docs/corporate-bank-accounts), [Activating Bank Account Details](https://docs.wirexapp.com/docs/corporate-account-activation), [Bank Transfers](https://docs.wirexapp.com/docs/corporate-bank-transfers), [Corridor Transfers](https://docs.wirexapp.com/docs/corporate-corridor-transfers), [Bulk Transfers](https://docs.wirexapp.com/docs/corporate-bulk-transfers), [Push to Card](https://docs.wirexapp.com/docs/corporate-push-to-card), [Card Transfer](https://docs.wirexapp.com/docs/corporate-card-transfer), [FX](https://docs.wirexapp.com/docs/corporate-fx).

## Table of Contents

- [Choosing a Payout Endpoint](#choosing-a-payout-endpoint)
- [Bank Account Activation](#bank-account-activation)
- [v1 / v2 Bank Transfers](#v1--v2-bank-transfers)
- [v3 Corridor Transfers](#v3-corridor-transfers)
- [Bulk Transfers](#bulk-transfers)
- [Push-to-Card](#push-to-card)
- [FX Swaps](#fx-swaps)
- [After Execution](#after-execution)
- [Errors](#errors)

---

## Choosing a Payout Endpoint

| You want to | Use |
|---|---|
| Pay a beneficiary described inline over SEPA, ACH or Faster Payments | v1 / v2 bank transfer |
| Pay a stored recipient over any rail (16 corridors) | v3 corridor transfer |
| Pay up to 50 on-chain crypto addresses at once | Bulk transfer |
| Pay an external Visa/Mastercard | Push-to-card (`/api/v1/cards/transfer`) |
| Convert one asset to another | FX |

Every transfer follows estimate then execute. Money is debited from the corporation wallet (the chosen token); estimates quote one entry per token in `estimated_amounts[]` and expire at `expires_at` (Unix seconds). There is no cancel endpoint for any of them, and no status lookup by id: track outcomes in `GET /api/v1/activity/feed`.

## Bank Account Activation

A corporate bank account is a set of fiat details in the corporation's own name (IBAN, routing + account number, sort code + account number, CLABE). Deposits credit the corporation's on-chain balance.

Activation:

1. `GET /api/v1/corporations` — the `*Account` capability must be exactly `ActivationNotStarted` (`AchAccount`, `SpeiAccount`, `FasterPaymentsAccount`). Any other status gives `400` / `Capability does not need activation`. The `actions[]` entries `ActivateAchDetails`, `ActivateSpeiDetails`, `ActivateSepaDetails` appear exactly when activation will be accepted.
2. `POST /api/v1/bank/accounts` (`TransactionSu`, `AccountSu` or `AccountCreate`):

```json
{
  "account_type": "Ach"
}
```

Response `{"details_id": "<details_uuid>"}`. `account_type` values per the reference: `Sepa`, `Swift`, `FasterPayment`, `Ach`, `Spei`. Currency mapping: `Ach` and `Spei` USD, `FasterPayment` GBP, `Sepa` EUR. If an `Active` account in that currency exists the details attach to it (activating SPEI after ACH reuses the same USD account).

Note: docs differ on SEPA. The reference schema lists `Sepa` as a valid `account_type`, but the Activating Bank Account Details guide says `Sepa` is rejected (`400 ErrorInvalidField`, `expected: Ach|Spei|FasterPayment`) because SEPA is provisioned automatically on verification, and that `Swift` is refused by the handler (`Invalid value for account type`). The Corporation Profile guide lists an `ActivateSepaDetails` action pointing at this endpoint. Follow the corporation's `SepaAccount` status and its `actions[]`; if the call is rejected, wait for `SepaAccount` to turn `Active` and read the details.

3. `GET /api/v1/bank/accounts` (`TransactionSu`, `TransactionCreate` or `AccountView`) — poll until details are `Active`; there is no activation webhook. Item: `id` (**composite** `<accountId>:<detailsId>`, two UUIDs joined by `:`), `currency`, `status` (`Active`, `Pending`, `Blocked`, `Closed`), `account_holder`, `account_type`, `created_at`, `details` (`iban`, `bic`, `account_number`, `sort_code`, `routing_number`, `clabe`, `mandatory_reference`).

If `details.mandatory_reference` is present the sender **must** put it in the transfer reference or the deposit cannot be matched; show it wherever account details are shown. Receiving capabilities differ by party (`SepaIn1stParty` vs `SepaIn3rdParty`, same for ACH and SPEI).

## v1 / v2 Bank Transfers

Rail (SEPA, ACH, Faster Payments) is implied by the details type behind `account_id`; there is no rail field. SPEI and SWIFT accounts are refused here (`400 ErrorNotSupported`, `Invalid account id`): use corridor transfers.

1. Estimate: `POST /api/v1/bank/transfer/estimate` (SEPA, Faster Payments) or `POST /api/v2/bank/transfer/estimate` (accepts `recipient` and `recipient_account`; **required for ACH**). Needs `TransactionSu` or `TransactionCreate`.

```json
{
  "account_id": "<accountId>:<detailsId>",
  "amount": 1000,
  "reference": "<comment>",
  "tokens": ["<token_address>"]
}
```

Response: `id` (the estimation id), `amount`, `currency`, `expires_at`, `estimated_amounts[]` (`amount`, `precise_amount`, `token_address`, `token_symbol`, `rate`, `fee_amount`, `fee_precise_amount`). `tokens` defaults to every token available to the corporation.

2. Execute: `POST /api/v1/bank/transfer`. Body: `account_id`, `token_address`, `recipient` (`first_name` + `last_name` for a person, or `company_name`), `recipient_account`, `reference`, and one of `estimation_id` (the estimate's `id`; uses the quoted rate) or `amount` (executes at current market rate). Sending neither is `400 ErrorMissingField`. Response `{"id": "<activity_id>"}`, the activity feed item id.

Beneficiary bank details by rail (`recipient_account`):

| Rail | Required fields |
|---|---|
| SEPA | `iban`, `bic` |
| ACH | `account_number`, `routing_number`, `legal_address` |
| Faster Payments | `account_number`, `sort_code` |

`legal_address` needs `line1`, `city`, `zip_code`, `country` (`line2`, `state` optional) and is triggered by the ACH field pair: any request with both `account_number` and `routing_number` needs it (`recipient account.legal address is required for ACH`).

Outbound capability checked: SEPA `SepaOut1stParty`, ACH `AchOut1stParty`, Faster Payments `FasterPaymentsOut3rdParty`. A corporation with only `SepaOut3rdParty` cannot use this endpoint for SEPA.

Settlement: Faster Payments near-instant, SEPA same or next business day, ACH one to three business days.

## v3 Corridor Transfers

Three calls; the third only for CPN corridors. All need `TransactionSu` or `TransactionCreate` and the corridor's capability `Active`.

| `{corridor}` | Rail | Currency | Capability | Provider |
|---|---|---|---|---|
| `sepa` | SEPA | EUR | `SepaOut3rdParty` | Bank |
| `ach` | ACH | USD | `AchOut3rdParty` | Bank |
| `faster-payments` | Faster Payments | GBP | `FasterPaymentsOut3rdParty` | Bank |
| `pix` | PIX | BRL | `PixOut3rdParty` | CPN |
| `spei` | SPEI | MXN | `SpeiOut3rdParty` | CPN |
| `fedwire` | FEDWIRE | USD | `FedwireOut3rdParty` | CPN |
| `swift` | WIRE | USD | `SwiftOut3rdParty` | CPN |
| `cips` | CIPS | CNY | `CipsOut3rdParty` | CPN |
| `chats` | CHATS | HKD | `ChatsOut3rdParty` | CPN |
| `fps_hk` | FPS | HKD | `FpsHkOut3rdParty` | CPN |
| `imps` | IMPS/NEFT/UPI | INR | `ImpsOut3rdParty` | Triple-A |
| `instapay` | InstaPay/PESONet | PHP | `InstapayOut3rdParty` | Triple-A |
| `bi-fast` | BI-FAST | IDR | `BiFastOut3rdParty` | Triple-A |
| `nip` | NIP | NGN | `NipOut3rdParty` | Triple-A |
| `ipp` | IPP | AED | `IppOut3rdParty` | Triple-A |
| `pse` | PSE | COP | `PseOut3rdParty` | Triple-A |

Corridor names are literal lowercase and spelled inconsistently: `faster-payments` and `bi-fast` hyphenated, `fps_hk` underscore. Unknown values give `400` / `Unknown or unsupported corridor: <value>`. No endpoint lists corridors at runtime.

Provider rules: Bank corridors require `account_id` and have no confirm step. CPN corridors need no `account_id` and require the confirm step. Triple-A corridors need neither. `CpnExternalProfile` and `TripleAExternalProfile` are provisioned by Wirex with no activation endpoint.

1. `POST /api/v3/bank/estimate/{corridor}`:

```json
{
  "recipient_id": "<recipient_uuid>",
  "recipient_payment_details_id": "<payment_details_uuid>",
  "destination_amount": 100,
  "destination_currency": "<currency>",
  "account_id": "<account_uuid>",
  "source_tokens": ["<token_address>"]
}
```

`destination_currency` defaults to the corridor currency; `account_id` only for `sepa`, `ach`, `faster-payments` and it is a **plain UUID**, not the composite id (`Invalid account ID format`). Response `id`, `amount`, `currency`, `expires_at`, `estimated_amounts[]`.

2. `POST /api/v3/bank/initiate/{corridor}` with `estimation_id`, `source_token_address` (one quoted), optional `reference`. Response `transfer_id`, `status` (e.g. `pending`), `required_actions[]`. An empty `required_actions` means the transfer is already moving; do not call confirm.

3. CPN only: when `required_actions` contains a `FundTransfer` (`data`: `chain_id`, `token_address`, `destination_address`, `amount` smallest unit string, `expires_at`), send that amount of that token to that address on that chain before `expires_at`, then `POST /api/v3/bank/confirm/{corridor}`:

```json
{
  "transfer_id": "<transfer_uuid>",
  "actions": [
    {
      "type": "FundTransfer",
      "data": {
        "tx_hash": "<funding_tx_hash>"
      }
    }
  ]
}
```

Response `transfer_id`, `status` (e.g. `processing`), `tx_hash`. Not confirming before `expires_at` abandons the transfer; a funded transfer cannot be recalled via the API.

## Bulk Transfers

Crypto destinations only; 1-50 recipients; one `currency` per batch. Two steps, and the API call alone moves no money.

1. `POST /api/v1/bulk/transfer` (`TransactionSu` or `TransactionCreate`) validates, **reserves** the batch total and approves it on-chain:

```json
{
  "recipients": [
    {
      "type": "Crypto",
      "currency": "WEUR",
      "amount": "1.50",
      "crypto": {
        "address": "<evm_address>",
        "network": "Base"
      }
    }
  ]
}
```

`type` must be `Crypto`; `currency` is a token symbol (use `WUSD` / `WEUR` for unified tokens); `amount` is a JSON number or decimal string, **truncated to two decimals** (below `0.01` becomes zero and still returns `200`); `crypto.network` must be non-empty but the batch always runs on the corporation token's chain; `crypto.address` is only checked for presence, so validate `^0x[0-9a-fA-F]{40}$` yourself (a bad address stays reserved 24 hours).

Response: `transaction_id` (the **corporation id**, same on every batch), `operation_id` (unique per batch; key your records on it), `crypto_transfers[]` (`address`, `precise_amount`, `token_address`). Check every `precise_amount` before step 2.

The reservation lasts 24 hours; an unexecuted batch keeps its total unavailable (a second approval can fail with `ErrorInsufficientFunds`). No cancel endpoint.

2. On-chain: the corporation wallet sends a UserOperation calling `FundsManagement.executeOutgoingBatchTransaction` (resolve `FundsManagement` with `contractByName("FundsManagement")` from the ContractRegistry). Arguments: `transactionId` and `operationId` as `bytes16` (the UUIDs with dashes removed), `tokenAddress` from `crypto_transfers[0].token_address`, `recipients` and `amounts` (`precise_amount` as `uint256`) in response order. The signer must be an employee whose on-chain role is `Su`, `TransactionSu` or `TransactionCreate`; gas is sponsored by the paymaster. Wirex never executes the batch. Retry `Batch transaction not found` every few seconds right after step 1 (the approval needs a few seconds to land); `Total amount mismatch` means `amounts` differ from the approved total. A batch executes once.
3. Confirm in `GET /api/v1/activity/feed`: one `Crypto` / `Outbound` / `Completed` item per recipient; match by `operations[].hash` (the step 2 hash) and `destination.wallet.address`. There is no `Failed` item and no bulk status endpoint or webhook.

## Push-to-Card

Credits an external Visa or Mastercard over OCT rails. Requires `CardSu` (not `TransactionCreate`) and the `CardTransfer` capability `Active`.

1. Tokenize the destination card in the PCI environment (separate host and credentials; the corporation token is not accepted): `POST {pci_base_url}/b2b/cards/oct?user_id=<corporation_address>`, body `card_number`, `cardholder_name` (uppercase as printed), `is_saved` (boolean); response `{"value": "<card_token>"}`. `user_id` is the **corporation wallet address**, not a user id. PCI hosts: `https://wx-acquiring-card-manager-uat.wirexapp.com` (sandbox) and `https://wx-acquiring-card-manager.wirexapp.com` (production); request access from Wirex.
2. Store it as a recipient payment detail of type `Card` (`card.card_id`, `card.card_pan_last`) with `POST /api/v2/recipients`. Either the token or `card.card_id` can be passed as `external_card_id`.
3. `POST /api/v1/cards/transfer/estimate`:

```json
{
  "external_card_id": "<card_token>",
  "amount": 250,
  "currency": "USD",
  "tokens": ["<token_address>"]
}
```

`amount` > 0; `tokens` at least one (**unified tokens like WUSD/WEUR accepted directly**); `currency` silently defaults to `USD`. Response `estimation_id`, `amount`, `currency`, `fee_amount`, `expires_at`, `estimated_amounts[]`.

4. `POST /api/v1/cards/transfer` with `estimation_id` and `token_address` (one of the quoted). Response `{"id": "<activity_id>"}`. No reversal; a completed OCT is final.

## FX Swaps

Needs `TransactionSu` and the `StableExchange` capability `Active` (both FX endpoints check `StableExchange`, not `FxTransfer`). Wirex does not debit the wallet; nothing moves until you pay the deposit address on-chain.

1. `POST /api/v1/fx/estimate`: `source_asset_address`, `destination_asset_address` (both **regular** tokens from `GET /api/v1/config/tokens`), **exactly one** of `source_asset_amount` / `destination_asset_amount` (positive decimal strings), optional `correlation_id` (UUID, not echoed back). Response: `estimation_id`, `deposit_address`, `source_asset_amount`, `destination_asset_amount`, `trade_rate`, `expiration_time` (ISO 8601).
2. Send exactly `source_asset_amount` of the regular `source_asset_address` token from the corporation wallet to `deposit_address` before `expiration_time` and keep the tx hash. A corporation holding unified tokens must unwrap and send the underlying token in the same operation; depositing a unified token is not matched.
3. `POST /api/v1/fx` with `estimation_id` and `payment_transaction_hash` (`0x`-prefixed, 66 characters). Response `{"trade_id": "<trade_uuid>"}`.

Settlement appears in the activity feed and via `/v2/webhooks/balances`; there is no FX webhook and no trade lookup. Re-estimate rather than retrying an expired `estimation_id`.

## After Execution

1. The chosen token is debited from the corporation wallet (directly, or via the funding transfer for CPN corridors and FX).
2. The payout is submitted on its rail.
3. The item appears in `GET /api/v1/activity/feed` under the returned `id`.
4. Progress arrives at `POST {your_webhook_base_url}/v2/webhooks/activities` and `/v2/webhooks/balances`. Webhooks are not retried; poll the feed.

See [WEBHOOKS-AND-ACTIVITY.md](WEBHOOKS-AND-ACTIVITY.md) and [RECIPIENTS.md](RECIPIENTS.md).

## Errors

| HTTP | Reason | Message | Fix |
|---|---|---|---|
| 400 | `ErrorGeneral` | `Capability is not active` | Required capability not `Active` (FX: `StableExchange`; card transfer: `CardTransfer`; corridors: the corridor capability or its provider profile) |
| 400 | `ErrorGeneral` | `Capability does not need activation` | Capability not `ActivationNotStarted` |
| 400 | `ErrorInvalidField` | `Invalid format for account id` | v1 wants the composite id; v3 wants a plain UUID |
| 400 | `ErrorNotFound` / `ErrorNotSupported` | `Invalid account id` | Not owned, or rail not SEPA/ACH/Faster Payments |
| 400 | `ErrorMissingField` | `amount is required when estimation id missing` | Send `estimation_id` or `amount` |
| 400 | `ErrorMissingField` | `recipient account.legal address is required for ACH` | Add `legal_address` |
| 400 | keyed | `Recipient not found or does not belong to you` | Recipient deleted or foreign |
| 400 | keyed | `Invalid recipient Payment Details ID` | Use `payment_details[].id` |
| 400 | `ErrorInvalidField` | `recipients exceeds maximum allowed` (`max: 50`), `Only crypto recipients are supported`, `All recipients must use the same currency` (`currency_mismatch`), `Recipient details are invalid` | Fix the bulk batch; errors name the entry as `recipients[i]` |
| 400 | `ErrorNotSupported` | `Invalid currency` (`unsupported_for_chain`) | No active token with that symbol on the chain |
| 400 | `ErrorInsufficientFunds` | `Insufficient funds` | Total exceeds the available (unreserved) balance |
| 500 | `ErrorGeneral` | `Failed to estimate card transfer`, `Failed to execute card transfer`, `Failed to estimate FX swap`, `Failed to execute FX swap` | Provider rejected, expired, already executed or lacking balance; re-estimate |
| 500 | `ErrorGeneral` | `Failed to read tokens` | Token catalogue unavailable; retry |
| 500 | `ErrorGeneral` | `Failed to request bulk transfer approval` | Read `GET /api/v1/wallets` before retrying; a reserved total is released after 24 hours |
