# RevenueCat Webhook Map

**Status:** Draft (Task 5 of Phase 2)
**Owner:** Backend (Node + Express on Hostinger VPS)
**Depends on:** `docs/api-contract.md` (§4.2 processing order, §2.1 HMAC auth), `docs/db/migrations/001_init.sql` (`users`, `webhook_events` tables)
**Source of truth:** This document for all RevenueCat webhook handling logic.

---

## 1. Overview

RevenueCat delivers webhook events to `POST /webhooks/revenuecat` when a user's subscription state changes. This document specifies:

- The common processing pipeline all events share (§2)
- Handler pseudocode for each of the 7 event types with explicit DB writes (§3)
- Edge cases: out-of-order delivery, duplicate IDs, sandbox vs prod, account transfers (§4)
- Acceptance checklist (§5)

**Entitlement identifier:** `gfm_premium`  
**Affected DB tables:** `users`, `webhook_events`

---

## 2. Common Processing Pipeline

Every incoming request runs through this pipeline before event-specific logic. Source of truth for the request-level behavior is `api-contract.md §4.2`; this doc adds implementation detail.

```typescript
app.post("/webhooks/revenuecat", rawBodyMiddleware, async (req, res) => {

  // ── Step 1: Verify HMAC ──────────────────────────────────────────────────
  // Compute HMAC-SHA256 over the raw request body (not the parsed JSON).
  // rawBodyMiddleware saves req.rawBody before body-parser runs.
  const computed = crypto
    .createHmac("sha256", process.env.RC_WEBHOOK_SECRET!)
    .update(req.rawBody)
    .digest("hex");
  if (!timingSafeEqual(Buffer.from(computed), Buffer.from(req.headers.authorization ?? ""))) {
    return res.status(401).json({ code: "invalid_signature",
      message: "Webhook signature verification failed." });
  }

  // ── Step 2: Parse and validate envelope ─────────────────────────────────
  const payload = req.body as RcEventPayload;
  const event   = payload?.event;
  if (!event?.id || !event?.type) {
    return res.status(400).json({ code: "invalid_input",
      message: "Malformed RevenueCat event payload." });
  }

  // ── Step 3: Dedupe on event_id ───────────────────────────────────────────
  // The INSERT is inside the same transaction as the user UPDATE (Step 6).
  // Here we do a fast pre-check to short-circuit before opening a transaction.
  // The real guard is the UNIQUE constraint on webhook_events.event_id.
  const existing = await db.query(
    "SELECT 1 FROM webhook_events WHERE event_id = $1", [event.id]
  );
  if (existing.rowCount > 0) {
    // Duplicate — RC retried a previously-delivered event. Silently ack.
    log.info({ event_id: event.id, type: event.type }, "rc_webhook_duplicate_skipped");
    return res.status(200).json({ received: true });
  }

  // ── Step 4: Sandbox gate ─────────────────────────────────────────────────
  const isSandbox = event.environment === "SANDBOX";
  if (isSandbox && process.env.NODE_ENV === "production") {
    // Store for audit; skip user update.
    await db.query(
      `INSERT INTO webhook_events (event_id, event_type, user_id, raw_payload)
       VALUES ($1, $2, NULL, $3)
       ON CONFLICT (event_id) DO NOTHING`,
      [event.id, event.type, payload]
    );
    log.info({ event_id: event.id, type: event.type }, "rc_webhook_sandbox_stored_noop");
    return res.status(200).json({ received: true });
  }

  // ── Step 5: Resolve user ─────────────────────────────────────────────────
  // RC app_user_id is the google_sub we stored at sign-in.
  const userRow = await db.query(
    "SELECT id FROM users WHERE google_sub = $1", [event.app_user_id]
  );
  if (userRow.rowCount === 0) {
    // Unknown user — config drift, not a transient error. Store and ack; do
    // NOT return 4xx (RC retries on non-200, creating an infinite loop).
    await db.query(
      `INSERT INTO webhook_events (event_id, event_type, user_id, raw_payload)
       VALUES ($1, $2, NULL, $3)
       ON CONFLICT (event_id) DO NOTHING`,
      [event.id, event.type, payload]
    );
    log.warn({ event_id: event.id, type: event.type, app_user_id: event.app_user_id },
      "rc_webhook_unknown_user");
    return res.status(200).json({ received: true });
  }
  const userId: number = userRow.rows[0].id;

  // ── Step 6: Apply event in a transaction ─────────────────────────────────
  await db.transaction(async (tx) => {

    // Insert webhook_events row first. ON CONFLICT handles the race between
    // the pre-check (Step 3) and now — two concurrent deliveries of the same
    // event_id both reach here; only one INSERT wins.
    const inserted = await tx.query(
      `INSERT INTO webhook_events (event_id, event_type, user_id, raw_payload)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (event_id) DO NOTHING`,
      [event.id, event.type, userId, payload]
    );
    if (inserted.rowCount === 0) {
      // Lost the race — another worker processed this event. Roll back and ack.
      throw new DuplicateEventError();
    }

    // Dispatch to event-specific handler (§3).
    await applyEvent(tx, userId, event);
  }).catch((err) => {
    if (err instanceof DuplicateEventError) return; // silent ack
    throw err; // re-throw → 503 database_unavailable; RC will retry
  });

  return res.status(200).json({ received: true });
});
```

### 2.1 `rawBodyMiddleware`

Body-parser normally consumes the stream and exposes only the parsed object, but HMAC verification needs the exact raw bytes:

```typescript
app.use("/webhooks/revenuecat", (req, _res, next) => {
  let data = Buffer.alloc(0);
  req.on("data", (chunk: Buffer) => { data = Buffer.concat([data, chunk]); });
  req.on("end", () => {
    (req as any).rawBody = data;
    next();
  });
});
```

This middleware runs **before** `express.json()` on this route.

### 2.2 RC event payload shape (relevant fields)

```typescript
interface RcEvent {
  id: string;
  type: string;
  app_user_id: string;           // google_sub of the purchasing user
  aliases: string[];             // all RC user IDs for this customer
  original_app_user_id: string;
  entitlement_ids: string[];     // ["gfm_premium"] when premium
  product_id: string;
  purchased_at_ms: number;       // epoch ms of this purchase
  expiration_at_ms: number | null; // end of current billing period; null for lifetime
  environment: "PRODUCTION" | "SANDBOX";
  store: "APP_STORE" | "PLAY_STORE" | "AMAZON" | "STRIPE";
  // BILLING_ISSUE only:
  grace_period_expiration_at_ms?: number;
  // TRANSFER only:
  transferred_from?: string[];
  transferred_to?: string[];
}
```

---

## 3. Event Handlers

`applyEvent` dispatches to the correct handler. Unknown types are stored (via the common pipeline) and logged; no user update.

```typescript
async function applyEvent(tx: Tx, userId: number, event: RcEvent): Promise<void> {
  switch (event.type) {
    case "INITIAL_PURCHASE": return handleInitialPurchase(tx, userId, event);
    case "RENEWAL":          return handleRenewal(tx, userId, event);
    case "CANCELLATION":     return handleCancellation(tx, userId, event);
    case "EXPIRATION":       return handleExpiration(tx, userId, event);
    case "BILLING_ISSUE":    return handleBillingIssue(tx, userId, event);
    case "REFUND":           return handleRefund(tx, userId, event);
    case "PRODUCT_CHANGE":   return handleProductChange(tx, userId, event);
    case "TRANSFER":         return handleTransfer(tx, userId, event);
    default:
      log.warn({ event_id: event.id, type: event.type }, "rc_webhook_unknown_type");
      // Row already inserted; no user update needed. Return cleanly.
  }
}
```

### 3.1 `INITIAL_PURCHASE`

User subscribed for the first time. Set premium, reset quota counter, set billing period end.

```typescript
async function handleInitialPurchase(tx: Tx, userId: number, event: RcEvent) {
  const newResetAt = msToTimestamp(event.expiration_at_ms);

  await tx.query(`
    UPDATE users SET
      is_premium          = true,
      ai_premium_used     = 0,
      premium_reset_at    = $2,
      grace_period_until  = null
    WHERE id = $1
      AND (premium_reset_at IS NULL OR $2 > premium_reset_at)
  `, [userId, newResetAt]);

  log.info({ user_id: userId, premium_reset_at: newResetAt }, "rc_initial_purchase");
}
```

**`$2 > premium_reset_at` guard:** if a RENEWAL for a later period already arrived (out-of-order), this INITIAL_PURCHASE is stale and must not overwrite the newer `premium_reset_at`. The `is_premium = true` write is safe — it's idempotent if already true. See §4.1 for full reasoning.

### 3.2 `RENEWAL`

Subscription renewed. Reset quota counter, advance billing period, clear any grace period.

```typescript
async function handleRenewal(tx: Tx, userId: number, event: RcEvent) {
  const newResetAt = msToTimestamp(event.expiration_at_ms);

  await tx.query(`
    UPDATE users SET
      is_premium          = true,
      ai_premium_used     = 0,
      premium_reset_at    = $2,
      grace_period_until  = null
    WHERE id = $1
      AND (premium_reset_at IS NULL OR $2 > premium_reset_at)
  `, [userId, newResetAt]);

  log.info({ user_id: userId, premium_reset_at: newResetAt }, "rc_renewal");
}
```

**Same guard as INITIAL_PURCHASE.** RENEWAL is also the event that clears `grace_period_until` — payment succeeded, billing issue resolved.

**RENEWAL arriving before INITIAL_PURCHASE:** no user row yet at the time the route handler runs is impossible (user must exist to have an RC subscription tied to their `google_sub`), but `premium_reset_at IS NULL` guard makes this safe regardless — RENEWAL will set the fields correctly and INITIAL_PURCHASE will be a no-op update when it arrives.

### 3.3 `CANCELLATION`

User cancelled but the subscription is **still active** until the current period ends. No `users` update — they remain premium. The EXPIRATION event (§3.4) is what revokes access.

```typescript
async function handleCancellation(tx: Tx, userId: number, event: RcEvent) {
  // No user table update. Cancellation = intent to not renew; access continues
  // until expiration_at_ms.
  log.info({ user_id: userId, expires_at: event.expiration_at_ms }, "rc_cancellation_noted");
}
```

### 3.4 `EXPIRATION`

Subscription period ended (after cancellation, failed billing, or natural end). Revoke premium.

```typescript
async function handleExpiration(tx: Tx, userId: number, event: RcEvent) {
  const eventExpiresAt = msToTimestamp(event.expiration_at_ms);

  // Only expire if this event's period matches or predates the stored period.
  // If premium_reset_at > eventExpiresAt, a newer RENEWAL already processed —
  // this EXPIRATION is for the old period. Do not revoke.
  const { rows } = await tx.query(
    "SELECT premium_reset_at FROM users WHERE id = $1 FOR UPDATE", [userId]
  );
  const storedResetAt: Date | null = rows[0]?.premium_reset_at ?? null;

  if (storedResetAt !== null && storedResetAt > eventExpiresAt) {
    log.info({ user_id: userId, event_expires_at: eventExpiresAt, stored_reset_at: storedResetAt },
      "rc_expiration_stale_skipped");
    return;
  }

  await tx.query(`
    UPDATE users SET
      is_premium         = false,
      grace_period_until = null
    WHERE id = $1
  `, [userId]);

  log.info({ user_id: userId }, "rc_expiration_revoked");
}
```

**Note:** `ai_premium_used` is **not** reset on expiration. We keep the historical count — it's used in cost calculations and debug queries. If the user re-subscribes, RENEWAL resets it.

### 3.5 `BILLING_ISSUE`

Payment failed. Apple retries for up to 16 days. User stays premium during grace period.

```typescript
async function handleBillingIssue(tx: Tx, userId: number, event: RcEvent) {
  // RC provides grace_period_expiration_at_ms for the Apple grace window.
  // Fall back to now + 16 days if absent (covers other stores or older RC versions).
  const gracePeriodUntil = event.grace_period_expiration_at_ms
    ? msToTimestamp(event.grace_period_expiration_at_ms)
    : new Date(Date.now() + 16 * 24 * 60 * 60 * 1000);

  // Only extend grace period if not already set further in the future.
  // Protects against duplicate BILLING_ISSUE events shortening an existing window.
  await tx.query(`
    UPDATE users SET
      grace_period_until = GREATEST(grace_period_until, $2)
    WHERE id = $1
  `, [userId, gracePeriodUntil]);

  // is_premium stays true — no change. User keeps access.

  log.info({ user_id: userId, grace_period_until: gracePeriodUntil }, "rc_billing_issue");
}
```

**`GREATEST` guard:** if two BILLING_ISSUE events arrive (e.g., RC retry + re-delivery), the grace period only ever extends, never shrinks.

#### 3.5.1 `BILLING_ISSUE` → `EXPIRATION` flow (full sequence)

```
T+0   BILLING_ISSUE received
      → is_premium = true (unchanged)
      → grace_period_until = T+16d

T+1   to T+16   Apple retries payment

      Branch A — payment succeeds:
        RENEWAL received
        → is_premium = true (already)
        → ai_premium_used = 0
        → premium_reset_at = new expiration date
        → grace_period_until = null (cleared)
        User never lost access. ✓

      Branch B — all retries fail:
        EXPIRATION received
        → is_premium = false
        → grace_period_until = null
        User loses premium access. ✓
```

The `grace_period_until` column on `users` lets `GET /user/status` surface a "billing issue" banner to the app (see `feature-spec-flutter.md §3.3`) without affecting the `is_premium` flag that gates the AI feature.

### 3.6 `REFUND`

Apple or Google issued a refund. Revoke premium immediately regardless of period.

```typescript
async function handleRefund(tx: Tx, userId: number, event: RcEvent) {
  await tx.query(`
    UPDATE users SET
      is_premium         = false,
      grace_period_until = null
    WHERE id = $1
  `, [userId]);

  log.info({ user_id: userId, product_id: event.product_id }, "rc_refund_revoked");
}
```

**Why no `expiration_at_ms` guard here:** refunds are an administrative action overriding the billing period. They should always revoke immediately. If the user purchases again after the refund, INITIAL_PURCHASE reinstates them.

**Note:** RC may send REFUND followed by EXPIRATION for the same period. EXPIRATION will attempt `is_premium = false` on an already-false row — the UPDATE is a no-op, which is correct.

### 3.7 `PRODUCT_CHANGE`

User changed plans (e.g., monthly → annual). Entitlement continues; update the billing period end. Do **not** reset quota — the subscription is ongoing.

```typescript
async function handleProductChange(tx: Tx, userId: number, event: RcEvent) {
  const newResetAt = msToTimestamp(event.expiration_at_ms);

  // entitlement_ids reflects the new product's entitlements.
  // If gfm_premium is still in the list, user stays premium.
  // (Product change to a non-premium product would appear as an EXPIRATION.)
  const stillPremium = event.entitlement_ids.includes("gfm_premium");

  await tx.query(`
    UPDATE users SET
      is_premium       = $2,
      premium_reset_at = CASE WHEN ($3::timestamptz > premium_reset_at OR premium_reset_at IS NULL)
                              THEN $3::timestamptz
                              ELSE premium_reset_at
                         END
      -- ai_premium_used intentionally NOT reset — quota continues across plan change
    WHERE id = $1
  `, [userId, stillPremium, newResetAt]);

  log.info({ user_id: userId, new_product: event.product_id, still_premium: stillPremium },
    "rc_product_change");
}
```

---

## 4. Edge Cases

### 4.1 Out-of-order event delivery

RC guarantees at-least-once delivery but **not** ordering. Events can arrive in any sequence, including:

| Scenario | Problem | Defence |
|---|---|---|
| RENEWAL before INITIAL_PURCHASE | RENEWAL sets `premium_reset_at = T2`; INITIAL_PURCHASE (with `T1 < T2`) arrives later | `$newResetAt > premium_reset_at` guard in §3.1 — INITIAL_PURCHASE becomes a no-op |
| Old-period EXPIRATION after a RENEWAL | EXPIRATION for period T1 arrives after RENEWAL already set `premium_reset_at = T2` | `storedResetAt > eventExpiresAt` check in §3.4 — EXPIRATION is skipped |
| Two RENEWALs out of order (monthly subscription, March arrives before February) | Second (older) RENEWAL would roll back quota and reset date | `$newResetAt > premium_reset_at` guard — older event is a no-op |
| BILLING_ISSUE arrives after RENEWAL for same period | Grace period set on an already-renewed subscription | `is_premium` is already true; `GREATEST` guard ensures `grace_period_until` only extends; harmless |
| EXPIRATION before CANCELLATION | Both from same period; CANCELLATION does nothing to `users` anyway | No issue — EXPIRATION fires correctly regardless |

**General principle:** every write to `premium_reset_at` is gated on `newValue > currentValue`. The `GREATEST` function handles `grace_period_until`. REFUND and EXPIRATION (same-period variant) are unconditional because they represent authority overrides, not continuations.

### 4.2 Duplicate event IDs

RC retries on 5xx. The dedupe mechanism is:

1. **Pre-check** (Step 3 in §2): fast `SELECT` before opening a transaction. Eliminates most duplicates cheaply.
2. **Transactional guard** (Step 6 in §2): `INSERT ... ON CONFLICT (event_id) DO NOTHING` inside the transaction. If `rowCount == 0` after the insert, another worker won the race — throw `DuplicateEventError` to roll back cleanly.

The UNIQUE constraint on `webhook_events.event_id` is the authoritative guard. The pre-check is an optimisation, not the safety net.

### 4.3 Sandbox vs production

| Environment | `NODE_ENV` | Behaviour |
|---|---|---|
| `SANDBOX` event | `production` | Store row (`user_id = null`), skip `users` update, return 200 |
| `SANDBOX` event | `staging` / `development` | Process normally (full `users` update) |
| `PRODUCTION` event | `staging` | Process normally (staging DB is isolated; no production data risk) |

RC sends sandbox events from TestFlight builds and from the RC dashboard "Send test event". Storing them (with `user_id = null` when the user is unknown) preserves an audit trail without polluting production entitlements.

Sandbox events **never** set `user_id` on the `webhook_events` row in production — we skip the `users.google_sub` lookup entirely to avoid matching a test `app_user_id` against a real user.

### 4.4 Transfer between accounts

RC sends a `TRANSFER` event when a subscription moves from one RC user ID to another (e.g., user changes their Apple ID). It is not in the 7 core events but must be handled to avoid ghost entitlements.

```typescript
async function handleTransfer(tx: Tx, _userId: number, event: RcEvent) {
  // transferred_from: RC user IDs losing the subscription
  // transferred_to:   RC user IDs gaining it
  // We look up both sets by google_sub.

  if (event.transferred_from?.length) {
    await tx.query(`
      UPDATE users SET is_premium = false, grace_period_until = null
      WHERE google_sub = ANY($1::text[])
    `, [event.transferred_from]);
  }

  if (event.transferred_to?.length) {
    await tx.query(`
      UPDATE users SET is_premium = true
      WHERE google_sub = ANY($1::text[])
    `, [event.transferred_to]);
    // No quota reset — this is an account migration, not a new billing period.
    // premium_reset_at is also left unchanged; the subscription's expiry hasn't moved.
  }

  log.info({
    transferred_from: event.transferred_from,
    transferred_to:   event.transferred_to,
  }, "rc_transfer");
}
```

Unknown `google_sub` values in either array are silently skipped (the `WHERE google_sub = ANY(...)` update touches 0 rows — safe).

### 4.5 Unknown `app_user_id`

If RC sends an event for an `app_user_id` not in `users.google_sub`:

- **Most likely cause:** config drift — RC was pointed at a different backend, or a test subscription used a fake user ID.
- **Action:** store the row (`user_id = null`), log `rc_webhook_unknown_user` at `WARN`, return 200.
- **Do not** return 4xx — RC treats non-200 as a delivery failure and retries indefinitely, which would spam logs and consume RC retry budget.

### 4.6 Unknown event type

RC periodically adds new event types. Any `type` not matched in the `switch` (§3):

- Row is stored in `webhook_events` (already done by the common pipeline before `applyEvent`).
- Log at `WARN` with the type name.
- Return 200.

This ensures forward-compatibility: when RC adds a new type, we don't error, we just ignore the user-update aspect until we add a handler.

### 4.7 DB write failure

If the transaction fails (Postgres unavailable, constraint violation, etc.):

- The error propagates out of `db.transaction()`.
- The route handler's catch re-throws it.
- Express error middleware converts it to `503 database_unavailable`.
- RC receives 5xx and **retries** — by design. Transient DB outages self-heal.

No partial writes escape the transaction. The `webhook_events` insert and the `users` update always commit together or not at all.

---

## 5. Utility

```typescript
function msToTimestamp(ms: number | null | undefined): Date | null {
  if (ms == null) return null;
  return new Date(ms);
}
```

`expiration_at_ms` is null for lifetime purchases (not expected for `gfm_premium` which is a recurring subscription, but handled defensively). When null, `premium_reset_at` is left unchanged in the handlers — the GREATEST/guard expressions treat NULL as "less than any date", so a null argument is a no-op.

---

## 6. Acceptance Checklist

- [x] **Each of 7 event types has a handler block with explicit DB writes**
  → §3.1 INITIAL_PURCHASE, §3.2 RENEWAL, §3.3 CANCELLATION (no-op), §3.4 EXPIRATION, §3.5 BILLING_ISSUE, §3.6 REFUND, §3.7 PRODUCT_CHANGE — all with explicit `UPDATE users SET ...` statements or documented rationale for why no update is needed.

- [x] **Dedupe-on-`event_id` shown as the first step**
  → §2 Step 3: fast pre-check `SELECT` before the transaction, plus transactional `INSERT ... ON CONFLICT DO NOTHING` as the authoritative guard (Step 6). Both work together to handle the concurrent-delivery race.

- [x] **`BILLING_ISSUE` → `EXPIRATION` flow walks through grace period correctly**
  → §3.5.1: full sequence diagram — BILLING_ISSUE sets `grace_period_until`, Branch A (RENEWAL clears it), Branch B (EXPIRATION clears it and sets `is_premium = false`). `GREATEST` guard prevents duplicate BILLING_ISSUE events from shrinking an existing grace window.

- [x] **Out-of-order delivery handled**
  → §4.1: table of all plausible OOO scenarios with the specific guard that handles each. Core mechanism: `premium_reset_at` is only advanced, never retracted, using the `newValue > currentValue` pattern.

- [x] **Sandbox events identified and either ignored in prod or routed separately**
  → §4.3: sandbox events in production are stored with `user_id = null` and skip all `users` updates; in staging/development they process normally.
