---
name: wirex-baas-pci-sdk
description: "Wirex BaaS PCI Compliant browser SDK (@wirexapp/card-topup-web, card-oct-web, card-reveal-web, card-3ds-web, card-react, card-sdk-web) — collects and reveals card data inside Wirex-served iframes so PAN/CVV never reach your page or servers. Covers setup (client id, registered parent origins, environments uat/prod, user-token getBearerToken), CSP rules (frame-src, script-src), top-up card collection (tokenizeTopUp -> cardId), payout card collection (tokenizeOctDestination -> externalCardId), reveal of PAN/expiry/CVV/PIN with action token, 3DS challenge element, appearance tokens and localization, React bindings, events, PciFrameRequestError and timeouts. Use when building browser card entry, card reveal or 3DS UI without entering PCI scope."
license: Apache-2.0
compatibility: "Requires network access. Compatible with Claude Code, Codex, and all Agent Skills spec tools."
metadata:
  author: wirex
  version: "1.0"
---

# Wirex BaaS PCI Compliant SDK

## Overview

A set of npm packages for browser apps. Each package mounts one or more iframes served from a Wirex-operated origin. The user types card data inside those iframes, which post it straight to Wirex and hand your page a token. Your DOM, JavaScript and servers never receive the PAN or CVV. Use it when your app collects or displays card data in a browser and you want it out of your PCI scope.

> **Not the same package as the TypeScript SDK.** `@wirexapp/wpay-baas-sdk` (skill `wirex-baas-sdk`) wraps the REST API and on-chain wallet operations. The PCI SDK covers only card-data surfaces. Installed and versioned independently; can be used together.

Docs describe version `1.0.0` (first stable release). All `@wirexapp/*` card packages release in lockstep because they share the frame message protocol: every `@wirexapp/card-*` entry and `@wirexapp/card-sdk-core` in your lockfile must show the same version, or the loader and frame refuse to communicate.

## Packages

| Package | Produces | Main creator |
|---------|----------|--------------|
| `@wirexapp/card-topup-web` | `cardId` for an external top-up card | `createCardTopUpFields` / `createCardTopUpForm` |
| `@wirexapp/card-oct-web` | `externalCardId` for a payout destination card | `createOctDestinationFields` / `createOctDestinationForm` |
| `@wirexapp/card-reveal-web` | In-frame display of PAN, expiry, CVV, PIN of an issued card | `createCardReveal` |
| `@wirexapp/card-3ds-web` | 3DS challenge outcome | `createThreeDsChallenge` |
| `@wirexapp/card-react` | React components and hooks over all of the above | see React section |
| `@wirexapp/card-sdk-core` | Shared foundation, installed automatically | none |
| `@wirexapp/card-sdk-web` | Umbrella re-exporting every package above | none |

## Setup

Inputs from Wirex onboarding:

| Input | What it is |
|-------|-----------|
| Client id | Non-secret UUID; `clientId` in SDK config, sent as `?client=<id>` on the frame URL. Not authorization, it only selects the origin allowlist |
| Registered parent origins | Exact `https://` origins of pages embedding the fields (staging and production separately; wildcard subdomains accepted after review). Held by Wirex as the frames' `frame-ancestors`. An unregistered origin renders an empty, blocked frame |
| User token | Per-user token from `POST /api/v1/user/authorize`, returned by your `getBearerToken` callback |
| Font CDN origin | Only needed with `fontUrl` / `fontFaces`; enters the frames' `font-src` |

There are no publishable keys, SDK secrets or rotation.

Install only what you use (`@wirexapp/card-sdk-core` comes as a dependency):

```bash
npm install @wirexapp/card-topup-web
npm install @wirexapp/card-oct-web
npm install @wirexapp/card-reveal-web
npm install @wirexapp/card-3ds-web
# React apps: npm install @wirexapp/card-react   (react >= 18 peer)
# Everything:  npm install @wirexapp/card-sdk-web
```

### Environments

Config is `{ environment, clientId }`; `environment` defaults to `'prod'`. You select an environment, never a URL.

| `environment` | Frame origin | Card data | Matching BaaS |
|---------------|--------------|-----------|---------------|
| `'prod'` | `https://frames.wirexapp.com` | Live | `https://api-baas.wirexapp.com` |
| `'uat'` | `https://frames.wirexapp.tech` | Test cards only | `https://api-baas.wirexapp.tech` |
| `'dev'` | `https://frames-dev.wirexapp.tech` | Test cards only | Wirex internal |

An unknown value throws at element creation: `PCI SDK: unknown environment "<value>" — expected 'dev', 'uat' or 'prod'.` A frame origin is bound to one backend: the bearer must come from the matching BaaS environment. Never self-host, bundle, cache or reverse-proxy the frame documents. Do not set `frameOrigin` / `framePath` (frame development only).

### Which token (user token only)

`getBearerToken: () => Promise<string>` must return a **user token**. S2S company tokens from `POST /api/v1/token` are not accepted and no identity headers substitute.

1. Backend: `POST /api/v1/token` (`grant_type: client_credentials`) -> S2S token, stays on backend.
2. Backend: `POST /api/v1/user/authorize` with the S2S token, `X-Chain-Id`, and exactly one of `X-User-Wallet` (the EOA, not the Smart Wallet), `X-User-Email`, `X-User-Id` -> `{ access_token, expires_at }`.
3. Send `access_token` to the browser over your session channel.
4. Refresh before `expires_at`.

The callback runs before each frame request, so return a fresh token every time. A token expiring between mount and submit is the most common cause of a failed tokenize.

| Element | When `getBearerToken` runs |
|---------|----------------------------|
| Per-field collect (`createCardTopUpFields`, `createOctDestinationFields`) | At tokenize only |
| Combined collect (`createCardTopUpForm`, `createOctDestinationForm`) | At mount and at tokenize |
| Reveal (`createCardReveal`) | At mount |

### Content Security Policy

```
Content-Security-Policy:
  frame-src https://frames.wirexapp.com;
  script-src 'self';
```

- `frame-src`: the frame origin for your environment (`https://frames.wirexapp.tech` in non-production) AND the 3DS orchestrator origin from your onboarding pack (the 3DS page is served by a Wirex backend origin, not the frame origin).
- `script-src 'self'`: the SDK is bundled from npm.
- No `connect-src` entry is needed; the SDK makes no network calls from your page.

### Timeouts

Frame ready handshake 10 s (`PCI frame did not become ready in time`); init or tokenize request 30 s (`PCI frame request timed out`). A mount timeout is usually an unregistered parent origin.

### Sandbox test cards

`4242 4242 4242 4242` (Visa) and `5555 5555 5555 4444` (Mastercard) tokenize successfully; any future expiry and any 3-digit CVV pass. Ask your Wirex contact for 3DS challenge / frictionless triggers.

## Top-up card collection (`@wirexapp/card-topup-web`)

Requires the `CardTopup` capability active (`GET /api/v2/user`). Two variants with identical config and result; per-field is recommended, do not mix them.

| | Per-field | Combined |
|---|-----------|----------|
| Creator | `createCardTopUpFields(sdk, config)` | `createCardTopUpForm(sdk, config)` |
| Iframes | one each: `number`, `expiry`, `cvv`, `name` | one, stock layout |
| Mount | `field(name).mount(container)` x4 | `mount(container)` once |

Config: `{ auth: { getBearerToken }, appearance?, strings?, onChange? }`. `appearance` and `strings` are read at mount only.

```javascript
import { createCardTopUpFields } from '@wirexapp/card-topup-web';

const topUp = createCardTopUpFields(
  { environment: 'uat', clientId: '<client-uuid>' },
  {
    auth: { getBearerToken: () => session.getAccessToken() },
    onChange: state => { submitButton.disabled = !state.complete; },
  },
);
await topUp.field('number').mount(document.querySelector('#card-number'));
await topUp.field('expiry').mount(document.querySelector('#card-expiry'));
await topUp.field('cvv').mount(document.querySelector('#card-cvv'));
await topUp.field('name').mount(document.querySelector('#card-name'));

const result = await topUp.tokenizeTopUp({
  billingDetails: { line1: '1 High Street', city: 'London', zipCode: 'N1 9GU', country: 'GB' },
  label: 'Personal Visa',
});
// { cardId, brand, bin, last4, expiryMonth, expiryYear }
```

1. Mount all four fields (the number field aggregates the others and issues the request).
2. Gate submit on `onChange` state `{ complete, brand: 'Visa' | 'MasterCard' | 'unknown', fields: { number: { valid, touched }, ... } }`.
3. `tokenizeTopUp({ billingDetails: { line1*, line2, city*, state, zipCode*, country* (ISO alpha-2) }, label? })`. `label` falls back to the typed cardholder name. Store only `cardId`; `bin` and `last4` are safe to display.
4. `POST /api/v1/cards/topup/estimate` with `external_card_id` = `cardId`, `destination_amount`, `destination_token_address`; then `POST /api/v1/cards/topup/execute` with `estimation_id`. Headers: `Authorization`, `X-User-Wallet`, `X-Chain-Id`, `Content-Type: application/json`.
5. If the execute response has `three_ds_state.url`, run the 3DS element (below).
6. `topUp.destroy()` on view unmount.

Throws: `Field "<name>" is not part of the "topup" profile`; `Field "<name>" already created for this group`; `The card-number field is not mounted`.

## Payout card collection (`@wirexapp/card-oct-web`)

Requires `CardTransfer` capability. Profile `oct-destination` renders the card-number field only (no CVV, no expiry).

```javascript
import { createOctDestinationFields } from '@wirexapp/card-oct-web';

const oct = createOctDestinationFields(sdk, { auth: { getBearerToken }, onChange });
await oct.field('number').mount(document.querySelector('#destination-card-number'));
const result = await oct.tokenizeOctDestination({
  cardholderName: 'JANE DOE', cardLabel: 'Sister - Visa', isSaved: true, isThirdParty: true,
});
// { externalCardId, brand, bin, last4 }
```

Params: `cardholderName` (required, uppercase as printed), `cardLabel` (required), `isSaved` (required), `isThirdParty` (required; `false` if sender is the cardholder), `userId` (optional UUID, sent as `user_id` query parameter).

1. Create recipient: `POST /api/v2/recipients` with `type: "Card"`, `card.card_id` = `externalCardId`, `card.card_pan_last` = `last4`.
2. `POST /api/v1/cards/transfer/estimate` with `external_card_id` = `externalCardId`, `currency`, `amount`, `tokens`.
3. `POST /api/v1/cards/transfer` with `estimation_id`, `token_address`.

`externalCardId` is the card token, not the recipient `payment_details[].id` (not accepted by transfer endpoints). Any other field name throws `Field "<name>" is not part of the "oct-destination" profile`. Third-party transfers carry extra compliance requirements: see the push-to-card docs.

## Reveal (`@wirexapp/card-reveal-web`)

Shows PAN, expiry, CVV, PIN in an iframe; copy-to-clipboard runs inside the frame (only reveal gets `clipboard-write`). Your page never sees values.

1. Mint a single-use `action_token` right before mounting (5 min validity, scope `GetCardDetails`, one token covers PAN/CVV/PIN of one reveal, no reuse): `POST /api/v1/confirmation/signature/verify` with `{ action_type: "GetCardDetails", message_signature, nonce }`. Signed message: `By signing this I confirm that I am executing action GetCardDetails at <nonce>` where `nonce` is Unix seconds. SMS OTP gives the same token under field name `token`.
2. Mount:

```javascript
import { createCardReveal } from '@wirexapp/card-reveal-web';

const reveal = createCardReveal(sdk, {
  cardId, actionToken,
  fetchDetails: true, fetchCvv: true,
  fields: ['cardholder', 'number', 'expiry', 'cvv'],
  cardholderName: 'ALEX GREY',
  auth: { getBearerToken: () => session.getAccessToken(), userEmail: user.email, userWallet: user.walletAddress },
  onStateChange: ({ status, errorMessage }) => { if (status === 'error') showToast(errorMessage); },
  onCopied: ({ field }) => analytics.track('card_detail_copied', { field }),
});
await reveal.mount(document.querySelector('#card-details'));
reveal.destroy(); // when the view closes
```

3. Frame calls `POST /api/v1/cards/{cardId}/details` (`number`, `expiry`), `/cvv` (`cvv`), `/pin` (`pin`); `cardholder` is rendered from `cardholderName`. Do not proxy these through your backend.

`onStateChange` status: `loading`, `ready` (at least one row loaded; partial failure shows an em dash in failed rows), `error` (every fetch failed; expired/consumed token, unknown card, wrong card status, backend failure). Option table and strings keys: [reference](references/REFERENCE.md#reveal-configuration).

## 3DS challenge (`@wirexapp/card-3ds-web`)

Runs the issuer challenge for an operation your app initiated (e.g. top-up execute returning `three_ds_state.url`). It is not the in-app approval flow for transactions on an issued Wirex card (webhook-driven, see `wirex-baas-cards`). No `three_ds_state` means no step-up needed.

```javascript
import { createThreeDsChallenge } from '@wirexapp/card-3ds-web';

const challenge = createThreeDsChallenge({
  url: execute.three_ds_state.url,           // must be https://
  onComplete: status => finishTopUp(status), // exactly once
  onError: message => { showToast(message); finishTopUp('Failed'); },
  onLoad: () => hideSpinner(),
  title: '3DS Verification',
});
challenge.mount(document.querySelector('#threeds-container'));
```

`onComplete` status (case-insensitive): `Completed` (continue), `Pending` (reconcile via activity feed / webhooks), `Failed` (report). Other values: unknown, send user to activity feed. Treat a user-cancelled challenge as `Pending`, not `Failed`. Give the container explicit size (issuer pages assume 500x480 or larger) and a light background; cancel UI is yours, call `destroy()`. Errors via `onError`: `3DS verification URL is invalid`, `3DS verification returned no status`. Double mount throws `ThreeDsChallenge is already mounted`. Messages are accepted only from the challenge URL's HTTPS origin and the iframe the element created.

## Appearance and localization

Frames accept whitelisted typed tokens, not CSS. Invalid values are dropped with a console warning. `theme` is `light` or `dark` (anything else renders light). Re-theming needs a new element.

```javascript
const appearance = {
  theme: 'dark',
  variables: { colorText: '#FFFFFF', borderRadius: '12px' },
  brandBadge: { style: 'logo', tone: 'color' },
};
```

All tokens, value grammars, brand fonts (file URL only, CORS, registered CDN origin) and brand badge options: [reference](references/REFERENCE.md#appearance-variables). Labels and validation messages come from `strings` (already translated, English defaults, unknown keys ignored).

## React (`@wirexapp/card-react`)

`react >= 18` peer; components are client-only and StrictMode safe. Components: `CardTopUpProvider` + `useCardTopUp()` (`{ ready, state, tokenizeTopUp }`), `OctDestinationProvider` + `useOctDestination()` (`{ ready, state, tokenizeOctDestination }`), fields `CardNumberField`, `CardExpiryField`, `CardCvvField`, `CardholderNameField`, plus `CardReveal`, `ThreeDsChallenge`, and `PciFrameRequestError`. Provider props: `sdk`, `auth`, `appearance`, `strings`, `onChange`, `onReady`, `onMountError`, `children`. Under `OctDestinationProvider` only `CardNumberField` is valid (others throw). Details: [reference](references/REFERENCE.md#react-bindings).

## Errors and events

- Frame-reported failures (init, tokenize) reject with `PciFrameRequestError` (`message`, `status?`). Mount/lifecycle failures reject with plain `Error`.
- `Validation failed — ...` means a field is invalid; the inline message is already visible, show nothing extra. Other backend errors: generic failure plus retry. `Network error`: retry. `Card service is not configured`: contact Wirex.
- Never log a tokenize result beyond `cardId`/`externalCardId`, brand and `last4`; never put them in URLs.
- Always `destroy()` elements on unmount; elements are single-use.

```javascript
try {
  await topUp.field('number').mount(el);
} catch {
  showToast('Failed to load the secure card form');
}
```

Full error tables: [reference](references/REFERENCE.md#error-messages).

## Going live checklist

- Production parent origins registered against the client id; font CDN origin registered if used
- `environment` is `'prod'` or omitted
- `frame-src` allows frame origin and 3DS orchestrator origin
- All `@wirexapp/card-*` packages on one version
- `getBearerToken` returns a user token, refreshed before `expires_at`
- Mount failures and `PciFrameRequestError` handled; `destroy()` on unmount

## Documentation

- https://docs.wirexapp.com/docs/retail-pci-sdk
- https://docs.wirexapp.com/docs/retail-pci-sdk-setup
- https://docs.wirexapp.com/docs/retail-pci-sdk-topup-collect
- https://docs.wirexapp.com/docs/retail-pci-sdk-payout-collect
- https://docs.wirexapp.com/docs/retail-pci-sdk-reveal
- https://docs.wirexapp.com/docs/retail-pci-sdk-3ds
- https://docs.wirexapp.com/docs/retail-pci-sdk-appearance
- https://docs.wirexapp.com/docs/retail-pci-sdk-react
- https://docs.wirexapp.com/docs/retail-pci-sdk-events
