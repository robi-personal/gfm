# Tasks

## Quota System Redesign

**Design decisions (agreed in conversation 2026-05-11):**

- Replace the two hard-coded tier limits (`FREE_LIMIT = 3`, `PREMIUM_LIMIT = 50` in `ai.routes.ts` and `user.routes.ts`) with a **credit-balance model**.
- Every user has a single `quota_balance` INTEGER. Events credit it; generations debit it. No caps — balance accumulates indefinitely.
- Three credit sources: (1) free monthly grant, (2) subscription purchase / renewal, (3) one-time top-up purchase.
- All product → quota-amount mappings are admin-configurable via a new `quota_products` DB table (not `server_config`), because it is a variable-length list keyed by product ID.
- Free tier: still exists; monthly amount is a row in `quota_products`. Unused free quota rolls over (same balance model as paid).
- Free grant is applied **lazily** on request (check `free_quota_reset_at < now`, credit if due, advance timestamp) — no cron job.
- On subscription `CANCELLATION` / `EXPIRATION`: mark `is_premium = false`, leave balance intact.
- RevenueCat idempotency: `webhook_events.event_id` (already PK) is the guard; no extra column needed.
- Existing users start migration with `quota_balance = free_monthly_quota` (as if freshly credited). The only current "premium" user (the developer) will be migrated to the whitelist instead, so no premium-aware seeding is needed.
- **Whitelist:** new `quota_whitelist` table keyed by email. Whitelisted users skip the quota gate entirely (no free-grant logic, no balance check, no debit, no `quota_transactions` rows). Admin manages the list via the admin panel.

---

### Q1 — DB Migration `002_quota_system.sql` — `sonnet`

File: `docs/db/migrations/002_quota_system.sql`

**`users` table changes:**
- DROP columns: `ai_free_used`, `ai_premium_used`, `free_month_reset_at`, `premium_reset_at`
- ADD `quota_balance INTEGER NOT NULL DEFAULT 0`
- ADD `free_quota_reset_at TIMESTAMPTZ` — when to next apply the free monthly grant; NULL = never credited yet
- ADD `subscription_product_id TEXT` — the active RevenueCat / App Store product ID (e.g. `gfm_weekly`); NULL for free users

**New table `quota_products`:**
```sql
CREATE TABLE quota_products (
  product_id   TEXT        PRIMARY KEY,
  product_type TEXT        NOT NULL CHECK (product_type IN ('subscription', 'topup', 'free')),
  display_name TEXT        NOT NULL,
  quota_amount INTEGER     NOT NULL CHECK (quota_amount >= 0),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

**Seed rows** (amounts are placeholders — admin sets real values before launch):
```
('free',           'free',         'Free Monthly',        3,  NOW())
('gfm_weekly',     'subscription', 'Weekly Premium',     15,  NOW())
('gfm_monthly',    'subscription', 'Monthly Premium',    50,  NOW())
('gfm_yearly',     'subscription', 'Yearly Premium',    700,  NOW())
('gfm_topup_10',   'topup',        'Top-up 10',          10,  NOW())
('gfm_topup_20',   'topup',        'Top-up 20',          20,  NOW())
('gfm_topup_30',   'topup',        'Top-up 30',          30,  NOW())
```
**Note:** `product_id` values must match App Store Connect / RevenueCat product IDs exactly. Update the seed before running migration.

**New table `quota_transactions`** (audit log):
```sql
CREATE TABLE quota_transactions (
  id          SERIAL      PRIMARY KEY,
  user_id     INTEGER     NOT NULL REFERENCES users (id),
  delta       INTEGER     NOT NULL,            -- positive = credit, negative = debit
  balance_after INTEGER   NOT NULL,
  source      TEXT        NOT NULL,            -- 'free_grant' | 'subscription' | 'topup' | 'generation'
  product_id  TEXT        REFERENCES quota_products (product_id),
  ref_id      TEXT,                            -- generation_id or webhook event_id
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX quota_transactions_user_idx ON quota_transactions (user_id, created_at DESC);
```

**New table `quota_whitelist`:**
```sql
CREATE TABLE quota_whitelist (
  email      TEXT        PRIMARY KEY,
  note       TEXT,                              -- optional reason / context
  added_by   TEXT,                              -- admin email or 'system'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
Email is stored case-insensitively — normalize to lowercase on insert and on lookup. Keyed by email (not `user_id`) so admins can pre-add an address before the user signs up.

**Seed row** (preserves the developer's current bypass-premium access):
```sql
INSERT INTO quota_whitelist (email, note, added_by)
VALUES ('robi.officee@gmail.com', 'developer — replaces is_premium bypass', 'system');
```

**Data migration for existing users:**
```sql
-- Everyone (including the one premium user — handled via whitelist seed above).
UPDATE users SET quota_balance = (
  SELECT quota_amount FROM quota_products WHERE product_id = 'free'
);
```

**DOWN section:** drop `quota_whitelist`, drop `quota_transactions`, drop `quota_products`, drop the new columns on `users`, and re-add the original columns (`ai_free_used`, `ai_premium_used`, `free_month_reset_at`, `premium_reset_at`) with their original definitions. **Note:** historical usage counters cannot be reconstructed from `quota_balance` — DOWN restores schema only, not data. Re-added counters will be zeroed.

---

### Q2 — Domain + Repository Layer — `sonnet`

**New entity:** `src/domain/entities/quota-product.ts`
```ts
export interface QuotaProduct {
  productId: string;
  productType: 'subscription' | 'topup' | 'free';
  displayName: string;
  quotaAmount: number;
  updatedAt: Date;
}
```

**New repository interface:** `src/domain/repositories/quota-product.repository.ts`
```ts
export interface QuotaProductRepository {
  getAll(): Promise<QuotaProduct[]>;
  getById(productId: string): Promise<QuotaProduct | null>;
  setAmount(productId: string, quotaAmount: number): Promise<void>;
}
```
(No `I` prefix — matches the codebase convention used by `UserRepository`, `ConfigRepository`, `WebhookEventRepository`.)

**New implementation:** `src/infrastructure/db/repositories/pg-quota-product.repository.ts`
- Straightforward SELECT / UPDATE on `quota_products`.

**New entity:** `src/domain/entities/quota-whitelist-entry.ts`
```ts
export interface QuotaWhitelistEntry {
  email: string;          // always lowercase
  note: string | null;
  addedBy: string | null;
  createdAt: Date;
}
```

**New repository interface:** `src/domain/repositories/quota-whitelist.repository.ts`
```ts
export interface QuotaWhitelistRepository {
  contains(email: string): Promise<boolean>;          // lowercases input
  getAll(): Promise<QuotaWhitelistEntry[]>;
  add(email: string, note: string | null, addedBy: string | null): Promise<QuotaWhitelistEntry>;
  remove(email: string): Promise<void>;
}
```

**New implementation:** `src/infrastructure/db/repositories/pg-quota-whitelist.repository.ts`
- All email lookups/inserts run through `LOWER(email)` to enforce case-insensitivity.
- `add` is upsert (`ON CONFLICT (email) DO UPDATE SET note = EXCLUDED.note, added_by = EXCLUDED.added_by`) so re-adding an existing email updates the note.

**Update `UserRepository`** (`src/domain/repositories/user.repository.ts`):
- REMOVE: `incrementFreeUsed`, `incrementPremiumUsed`, `resetFreeQuotaIfExpired`
- ADD:
  ```ts
  creditQuota(userId: number, amount: number, source: string, productId?: string, refId?: string): Promise<void>;
  debitQuota(userId: number, amount: number, refId: string): Promise<void>;
  applyFreeGrantIfDue(userId: number, freeProduct: QuotaProduct): Promise<void>;
  getQuotaBalance(userId: number): Promise<number>;
  setSubscriptionProduct(userId: number, productId: string | null): Promise<void>;
  ```

**Update `PgUserRepository`:**
- `creditQuota`: `UPDATE users SET quota_balance = quota_balance + $amount WHERE id = $userId` + insert into `quota_transactions`.
- `debitQuota`: same but subtract; no-op if balance already 0 (guard against race, generation gate prevents reaching here).
- `applyFreeGrantIfDue`: if `free_quota_reset_at IS NULL OR free_quota_reset_at <= NOW()`, call `creditQuota` with `source = 'free_grant'` and set `free_quota_reset_at = NOW() + INTERVAL '30 days'`. Wrap in a transaction with `SELECT … FOR UPDATE` on the user row to prevent double-credit under concurrent requests.
- `setSubscriptionProduct`: updates `subscription_product_id` and `is_premium`.

---

### Q3 — Generation Route Update — `sonnet`

File: `gfm_mw/src/presentation/routes/ai.routes.ts`

- **Remove** `FREE_LIMIT = 3` and `PREMIUM_LIMIT = 50` constants.
- Inject `QuotaWhitelistRepository` alongside `UserRepository`.
- **Whitelist short-circuit** — at the top of the quota path:
  ```ts
  const isWhitelisted = await whitelistRepo.contains(req.user!.email);
  ```
  If `isWhitelisted`, skip `applyFreeGrantIfDue`, skip the balance check, and skip the post-success `debitQuota` call entirely. Whitelisted generations leave no `quota_transactions` row (the per-generation audit lives in `ai_generations`).
- **Otherwise** (non-whitelisted):
  - **Before quota gate**, call `userRepo.applyFreeGrantIfDue(user.id, freeProduct)`.
  - **Quota gate** (replace current `used + quotaCost > limit` check):
    ```ts
    const balance = await userRepo.getQuotaBalance(user.id);
    if (balance < quotaCost) {
      // 429 quota_exceeded — include balance and quotaCost in response
    }
    ```
  - **After success**, call `userRepo.debitQuota(user.id, quotaCost, generationId)`.
- Update `getQuotaSnapshot()` response shape:
  ```ts
  { balance: number, quotaCost: number, unlimited: boolean }
  ```
  For whitelisted users: `{ balance: 0, quotaCost, unlimited: true }`. For everyone else: `unlimited: false`. The Flutter UI keys off `unlimited` to render "Unlimited" instead of a number.

File: `gfm_mw/src/presentation/routes/user.routes.ts`
- **Remove** duplicate `FREE_LIMIT` / `PREMIUM_LIMIT` constants.
- Inject `QuotaWhitelistRepository`.
- Update `/user/status` response to return `quotaBalance` and `unlimited` (true if email is whitelisted) instead of `used` / `limit`.

---

### Q4 — RevenueCat Webhook — `sonnet`

File: `gfm_mw/src/presentation/routes/webhook.routes.ts` (handler lives in `applyEvent` switch starting at ~line 43)

- Inject `QuotaProductRepository` alongside `UserRepository`.
- **`INITIAL_PURCHASE`** (subscription):
  1. Look up `quota_products` by `event.product_id`.
  2. Call `userRepo.creditQuota(userId, product.quotaAmount, 'subscription', product.productId, event.id)`.
  3. Call `userRepo.setSubscriptionProduct(userId, product.productId)`.
- **`RENEWAL`**: same as `INITIAL_PURCHASE` (idempotency guard via `webhook_events` PK already handles duplicate delivery).
- **`NON_RENEWING_PURCHASE`** (top-up — NEW; not currently handled):
  1. Look up product.
  2. `creditQuota(userId, product.quotaAmount, 'topup', product.productId, event.id)`.
- **`CANCELLATION`**: keep current no-op behavior — RC sends this when the user disables auto-renew, but access stays valid until `EXPIRATION`. Do NOT call `setSubscriptionProduct(userId, null)` here; that would revoke premium too early.
- **`EXPIRATION`**:
  1. `setSubscriptionProduct(userId, null)` — sets `is_premium = false`, clears `subscription_product_id`.
  2. Do NOT touch `quota_balance` (residual credits roll forward).
- **Existing handlers to leave intact** (none touch `quota_balance` — they only manage premium/grace state):
  - `BILLING_ISSUE` → `userRepo.setGracePeriod(...)` — no quota change.
  - `REFUND` → `userRepo.revokeImmediately(...)` — should also call `setSubscriptionProduct(userId, null)`; do NOT debit the original credit (the audit trail in `quota_transactions` is the record of truth, and clawing back balance can drive it negative).
  - `PRODUCT_CHANGE` → `userRepo.updateProductChange(...)`. Also call `setSubscriptionProduct(userId, event.product_id)` so the new plan id is tracked. Quota for the new plan is credited on the next `RENEWAL` event, not here.
  - `TRANSFER` → `userRepo.transferFrom(...)` / `transferTo(...)` — leave as-is.
- If `product_id` is not found in `quota_products`, log a warning and return 200 (don't crash webhook delivery).

---

### Q5 — Admin API — `sonnet`

File: `gfm_mw/src/presentation/routes/admin.routes.ts`

Add new endpoints (all behind existing `adminAuthMiddleware`):

**Quota products:**
```
GET   /admin/quota-products             → list all QuotaProduct rows ordered by product_type, display_name
PATCH /admin/quota-products/:productId  → body: { quotaAmount: number } (positive integer)
                                         updates quota_products.quota_amount + updated_at
                                         returns updated row
```
Validation: `quotaAmount` must be a positive integer. Unknown `productId` → 404.

**Whitelist:**
```
GET    /admin/whitelist                 → list all entries ordered by created_at DESC
POST   /admin/whitelist                 → body: { email: string, note?: string }
                                         normalizes email to lowercase; upserts; sets added_by
                                         from the admin's session/token; returns the entry
DELETE /admin/whitelist/:email          → removes the entry (case-insensitive match); 204 on success
```
Validation: `email` must match a basic email regex (no need for full RFC 5322); `note` max 500 chars. Unknown email on DELETE → 404.

---

### Q6 — Admin UI — `sonnet`

**File: `gfm_mw/admin/src/pages/QuotaProductsPage.tsx`**
- On mount: `GET /admin/quota-products`.
- Render a table with columns: Display Name | Type (badge: blue=subscription, green=topup, grey=free) | Quota Amount.
- Quota Amount cell: shows current value; click → inline `<input type="number" min="0">` → on blur/Enter call `PATCH /admin/quota-products/:productId` → update local state.
- Show a note: "Product IDs must match App Store Connect / RevenueCat product IDs exactly."

**File: `gfm_mw/admin/src/pages/WhitelistPage.tsx`**
- On mount: `GET /admin/whitelist`.
- Top of page: add-form row — email input + note input (optional) + "Add" button → `POST /admin/whitelist` → prepend new row to the local list.
- Render a table with columns: Email | Note | Added By | Created At | (delete button).
- Delete button: confirm dialog → `DELETE /admin/whitelist/:email` → remove from local list.
- Show a note: "Whitelisted users have unlimited generations and bypass all quota checks."

**File: `gfm_mw/admin/src/App.tsx`**
- Add two nav items in the "Operations" section alongside Rate Limits: `"Quota Products"` (route `/admin/quota-products`) and `"Whitelist"` (route `/admin/whitelist`).
- Add matching entries to the `PAGE_TITLES` map and `<Routes>` block.

---

### Q7 — Flutter Client — `sonnet`

**`lib/features/ai_form_builder/domain/entities/quota_snapshot.dart`:**
- Replace `used` / `limit` fields with `balance: int`, `quotaCost: int`, `unlimited: bool`.
- Drop `tier` and `resetsAt` (no longer meaningful in the balance model — there is no per-tier limit, and free grants accrue silently to balance).
- Keep `youtubeMinutesUsed` / `youtubeMinutesLimit` / `youtubeMinutesResetsAt` (YouTube minute cap is a separate, deferred system — out of scope for this redesign).
- Update `remaining` getter → returns `balance`; update `isExhausted` → `!unlimited && balance < quotaCost`.
- Update `fromJson` to read `balance` / `quotaCost` / `unlimited` and stop reading `used` / `limit` / `tier` / `resetsAt`.

**`lib/features/ai_form_builder/domain/entities/user_status.dart`:**
- Drop `aiFreeUsed`, `aiFreeLimit`, `aiPremiumUsed`, `aiPremiumLimit`, `effectiveUsed`, `effectiveLimit`.
- Add `quotaBalance: int` and `unlimited: bool`.
- Update `fromJson` to match the new `/user/status` shape from Q3.

**`lib/features/ai_form_builder/data/datasources/ai_form_datasource.dart`:**
- Update the `/ai/generate` envelope parser to construct the new `QuotaSnapshot` shape.

**`lib/features/ai_form_builder/presentation/cubit/ai_form_builder_cubit.dart`:**
- Rewrite `_applyQuota` (currently lines ~401-422) — instead of folding `q.used` / `q.limit` back into the per-tier `UserStatus` fields, it should just update `quotaBalance` and `unlimited` from `q`. The whole tier-based branching disappears.

**UI widgets:**
- Quota display: if `unlimited` → render `"Unlimited"` (no number). Else → render `"$balance generations remaining"`.
- Any widget keyed off `tier == QuotaTier.premium` for label purposes can fall back to `userStatus.isPremium` (still on `UserStatus`).

**Error codes:** no new ones expected; `quota_exceeded` error still uses the same key.

---

## Previously planned tasks (status)

| Task | Status |
|------|--------|
| 1 — Weekly/monthly spend caps | Removed — budget capping delegated to Google AI Studio (2026-05-10) |
| 2 — Admin panel (config, rate limits, UI) | Done (2026-05-10) |
| 3 — YouTube minute cap | Deferred — not yet implemented |
