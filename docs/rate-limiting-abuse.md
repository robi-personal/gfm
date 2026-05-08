# Rate Limiting, Abuse Defense & Kill Switches

**Status:** Draft (Task 6 of Phase 2)
**Owner:** Backend (Node + Express on Hostinger VPS)
**Depends on:** `docs/api-contract.md` (§3 endpoints, §6 error codes), `docs/ai-prompt-spec.md` (§5 pipeline)
**Source of truth:** This document. Specific numbers (rate limits, timeouts, USD caps) are tunable — version-bump this doc when changing.

---

## 1. Goals

Bound the blast radius of every plausible abuse vector against the AI middleware:

1. **Cost.** A determined attacker cannot run up our Gemini bill faster than we can detect and stop it.
2. **Availability.** A burst from one user / one IP / one bot cannot starve other users.
3. **Surface.** No server-side fetcher can be turned into an SSRF probe or a payload-shipping tool.
4. **Operability.** When something goes wrong, on-call can flip a switch in under 60 seconds without DB access.

**Non-goals.**
- Web-application-firewall rules (Cloudflare, ModSecurity) — defer until we see real attack patterns.
- DDoS mitigation at the network layer — Hostinger / Nginx defaults are sufficient for MVP.
- Detection-evasion-grade obfuscation defenses — out of scope; rely on auth + cost caps.

---

## 2. Threat model

What we are defending against, ranked by likelihood:

| Threat | Likelihood | Worst-case if undefended |
|---|---|---|
| Honest user clicks "Generate" 50× while debugging | High | Tens of wasted Gemini calls / user |
| User exploits validation_error → no quota burn → grind attack for free generations | Medium | Unlimited Gemini spend on one account |
| Scraper / scripted abuse using a leaked or shared Google account | Medium | Unbounded cost until quota cap hits |
| SSRF via `urls` input (private IP / metadata service) | Medium | Internal network probing, IMDS exfil |
| Oversized PDF/HTML body to exhaust memory or bandwidth | Low | Process OOM |
| Prompt-injected URL content that steers Gemini | Low | Bad form generated; bounded by Zod |
| Malicious RC webhook delivery from a compromised secret | Low | Spurious entitlement grants |
| DNS rebinding to slip past initial IP allowlist check | Low | SSRF after first request resolves |

Layers below are sized so no single failure exposes the whole service.

---

## 3. Defense layers

Top to bottom — each request hits these in order:

```
                           Internet
                              │
             ┌────────────────▼────────────────┐
             │ Nginx                            │
             │  - TLS termination               │
             │  - client_max_body_size 8M       │
             │  - $real_ip from CF / forwarded  │
             │  - Static rate limit (rough cap) │
             └────────────────┬────────────────┘
                              │
             ┌────────────────▼────────────────┐
             │ Express middleware stack         │
             │  1. requestId + log start        │
             │  2. body-parser limit 8M         │
             │  3. kill-switch checks           │
             │     (AI_GENERATION_DISABLED,     │
             │      USER_DENYLIST,              │
             │      MAX_DAILY_GEMINI_SPEND)     │
             │  4. global rate limit            │
             │  5. per-IP rate limit            │
             │  6. auth (Google ID token)       │
             │  7. per-user rate limit          │
             │  8. per-user 24h cost breaker    │
             │  9. route handler                │
             └────────────────┬────────────────┘
                              │
                  ┌───────────▼──────────┐
                  │ Route handlers        │
                  │  /ai/generate         │
                  │   - input validation  │
                  │   - URL fetcher (SSRF │
                  │     guards, §6)       │
                  │   - quota gate        │
                  │   - Gemini call       │
                  └──────────────────────┘
```

The kill switches sit **before** rate limiting so flipping them costs zero work — instant 503 with no Gemini call, no DB hit beyond a single dedupe-cache lookup.

---

## 4. Rate limits

### 4.1 Per-endpoint table

All limits are **enforced** unless noted. Numbers are MVP defaults — tune via env vars (§4.7), not code edits.

| Endpoint | Scope | Window | Limit | Env var | Action when exceeded |
|---|---|---|---|---|---|
| `POST /ai/generate` | global | 1 hour | 300 | `RL_AI_GLOBAL_HOURLY` | 503 `service_busy` |
| `POST /ai/generate` | per-IP | 1 hour | 30 | `RL_AI_IP_HOURLY` | 429 `rate_limited` |
| `POST /ai/generate` | per-user | 1 hour | 10 | `RL_AI_USER_HOURLY` | 429 `rate_limited` |
| `POST /ai/generate` | per-user | 1 day | 50 | `RL_AI_USER_DAILY` | 429 `rate_limited` |
| `GET /user/status` | per-user | 1 minute | 60 | `RL_STATUS_USER_MIN` | 429 `rate_limited` |
| `POST /webhooks/revenuecat` | per-IP | 1 minute | 120 | `RL_RC_IP_MIN` | 429 `rate_limited` |
| Catch-all (everything else) | per-IP | 1 minute | 120 | `RL_DEFAULT_IP_MIN` | 429 `rate_limited` |

#### Why these numbers

- **`/ai/generate` global 300/hour.** Each request can trigger up to 2 Gemini calls (initial + 1 repair, see ai-prompt-spec.md §5). 300 × 2 = 600 Gemini/hour, which is below the Gemini 2.0 Flash free-tier 15 RPM × 60 = 900/hour ceiling. Safety factor 1.5×.
- **Per-IP 30/hour.** Tolerates a small office / coffee-shop NAT (3–10 simultaneous users at typical pace). Stricter than per-user × 3 because honest users don't share IPs that aggressively.
- **Per-user 10/hour, 50/day.** The 10/hour is the grind-attack defense (see §9). The 50/day acts as a slow-burn cap that exceeds even a maxed-out premium user (50/month) so it only trips on abuse.
- **`/user/status` 60/minute.** UI polls this on the AI Form Builder screen; a worst-case stuck-in-loop client gets bounded but never visibly throttled.

### 4.2 Algorithm

**Sliding-window counter** with second-resolution buckets, stored in **Redis** (single instance, same VPS). Implementation: `rate-limiter-flexible` with `RateLimiterRedis`. Memory fallback (`RateLimiterMemory`) only if Redis is unreachable, with a warning log — single-process operation tolerates loss of accuracy across PM2 reload.

Why sliding window over token bucket: we want a hard "no more than N in the last hour" guarantee, not a refill-rate model. Sliding handles burst-then-quiet honestly.

### 4.3 Identifier choice

| Scope | Key |
|---|---|
| global | constant string `"global"` |
| per-IP | client IP from §4.4 |
| per-user | `users.id` (integer PK), looked up by `google_sub` |

**Never key on `email`** — emails change, and two `google_sub` values can share an email after a user changes their primary address.

**Anonymous requests** (no valid token) get only the per-IP and global buckets. They bypass per-user checks because they fail auth first.

### 4.4 Client IP detection

Nginx sits in front of Express. Trusting `X-Forwarded-For` blindly is an anti-pattern (clients can spoof). Configuration:

```nginx
# /etc/nginx/sites-enabled/api.conf
set_real_ip_from 127.0.0.1;            # local Nginx → Express
set_real_ip_from 10.0.0.0/8;           # any internal LB if added later
real_ip_header X-Forwarded-For;
real_ip_recursive on;

location / {
  proxy_pass http://127.0.0.1:3000;
  proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  proxy_set_header X-Real-IP $remote_addr;
}
```

In Express:

```ts
app.set("trust proxy", "loopback");      // trust only Nginx
const clientIp = req.ip;                 // resolved by Express against trust proxy
```

`trust proxy: "loopback"` (not `true`, not a count) — narrowest possible trust. Anything beyond Nginx is a spoof and we'd rather rate-limit the LB than every "user".

### 4.5 Response headers

Every `/ai/generate` response (success or 429) includes:

```
X-RateLimit-Limit: 10
X-RateLimit-Remaining: 7
X-RateLimit-Reset: 1731340800            # unix seconds, when the user bucket refills
```

These reflect the **most restrictive bucket the request hit** (per-user > per-IP > global). On 429:

```
Retry-After: 312                          # seconds until this bucket has room
```

`Retry-After` value:

- For `rate_limited` 429: seconds until the limiting bucket has 1 free slot.
- For `quota_exceeded` 429 (different code, different cause): seconds until `resetsAt`. Both are also in the body per api-contract.md §6.

Standard library (`rate-limiter-flexible`) returns `msBeforeNext` — divide by 1000, ceil.

### 4.6 Error responses

All limit-class failures use the api-contract.md §6 envelope:

```json
{
  "code": "rate_limited",
  "message": "Too many requests. Try again in 5 minutes.",
  "details": { "retryAfter": 312, "scope": "per-user" }
}
```

`scope` is `"global" | "per-ip" | "per-user-hourly" | "per-user-daily"`. Useful in logs; clients should branch on `code`, not `scope`.

`service_busy` (503) is the global-cap variant — distinct from `rate_limited` so clients can show "Service is unusually busy" instead of a personal "you're going too fast" message.

### 4.7 Tunability

All limits read from env at process boot — change requires `pm2 reload`. We do **not** support live re-tuning; a stale limit for 30 seconds during a reload is acceptable, and the simpler config story is worth more than hot-reload complexity.

### 4.8 Idempotency replay carve-out

When `/ai/generate` is a cache hit (same `Idempotency-Key` + same body, prior success — see api-contract.md §5), the request:

- **Counts** against per-IP and global buckets (still a request landing on us).
- **Does not count** against per-user hourly/daily buckets (the work was already done; charging the user again would punish honest retries on flaky networks).

Implemented by checking idempotency cache **before** the per-user bucket consume, then conditionally consuming.

---

## 5. Request size limits

Two layers, both enforced. The smaller one wins; we keep them aligned.

### 5.1 Nginx

```nginx
client_max_body_size 8m;          # 5MB PDF base64-encoded ≈ 6.7MB; 8M gives headroom
client_body_buffer_size 128k;
client_body_timeout 30s;
```

Oversized bodies get **413 Request Entity Too Large** at the Nginx layer — the request never reaches Node, never burns event-loop time.

### 5.2 Express

```ts
app.use(express.json({
  limit: "8mb",
  // body-parser will throw 413 PayloadTooLargeError; our error middleware
  // converts to:  { code: "invalid_input", message: "Request body too large." }
}));
```

### 5.3 PDF base64 size enforcement

The api-contract limit is "≤ 5MB decoded" for `inputType: "pdf"` and `book`. Pseudocode in the route handler:

```ts
if (body.inputType === "pdf" || body.inputType === "book") {
  const decodedBytes = Math.floor(body.fileBase64.length * 0.75);
  if (decodedBytes > 5 * 1024 * 1024) {
    return res.status(400).json({
      code: "file_too_large",
      message: "PDF must be 5 MB or smaller.",
      details: { maxBytes: 5_242_880, actualBytes: decodedBytes },
    });
  }
}
```

Done **before** Gemini call but **after** auth — no point burning Gemini tokens validating a too-large file.

---

## 6. URL fetcher safeguards (SSRF defense)

`inputType: "urls"` is the only place the server fetches user-supplied URLs. This is the biggest abuse surface; treat it accordingly.

### 6.1 Threat model

What an attacker tries with the `urls` input:

1. **Cloud metadata exfil** — `http://169.254.169.254/latest/meta-data/`.
2. **Internal service probe** — `http://10.0.0.1/admin`, `http://localhost:5432/`.
3. **DNS rebinding** — register a domain whose first DNS resolution is public, second is private.
4. **Redirect-based bypass** — public URL 302s to `file:///etc/passwd` or a private IP.
5. **Slow-loris / large-body exhaustion** — endpoint that drips 1B/sec for hours.
6. **Wrong content-type smuggling** — `text/html` URL returns 50MB of binary garbage.

### 6.2 IP filter (the core SSRF defense)

```ts
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import ipaddr from "ipaddr.js";

const BLOCKED_RANGES = [
  // IPv4
  "0.0.0.0/8",          // current network
  "10.0.0.0/8",         // RFC1918 private
  "100.64.0.0/10",      // CGNAT
  "127.0.0.0/8",        // loopback
  "169.254.0.0/16",     // link-local + cloud metadata
  "172.16.0.0/12",      // RFC1918 private
  "192.0.0.0/24",       // IETF protocol assignments
  "192.0.2.0/24",       // TEST-NET-1
  "192.168.0.0/16",     // RFC1918 private
  "198.18.0.0/15",      // benchmark
  "198.51.100.0/24",    // TEST-NET-2
  "203.0.113.0/24",     // TEST-NET-3
  "224.0.0.0/4",        // multicast
  "240.0.0.0/4",        // reserved
  "255.255.255.255/32", // broadcast
  // IPv6
  "::/128",             // unspecified
  "::1/128",            // loopback
  "fc00::/7",           // unique-local
  "fe80::/10",          // link-local
  "ff00::/8",           // multicast
  "::ffff:0:0/96",      // IPv4-mapped — re-check the v4 part
  "64:ff9b::/96",       // IPv4/IPv6 translation
];

function isPublicIp(addr: string): boolean {
  const parsed = ipaddr.parse(addr);
  for (const range of BLOCKED_RANGES) {
    const [network, prefix] = range.split("/");
    if (parsed.kind() === ipaddr.parse(network).kind()
        && parsed.match(ipaddr.parseCIDR(range))) {
      return false;
    }
  }
  return true;
}

async function resolveAndCheck(hostname: string): Promise<string> {
  // resolve all A/AAAA records — defeat single-record rebinding
  const records = await lookup(hostname, { all: true });
  if (records.length === 0) throw new FetchError("no_dns_records");
  for (const r of records) {
    if (!isPublicIp(r.address)) {
      throw new FetchError("private_ip_resolved", { ip: r.address });
    }
  }
  // Return the first one for connection. Actual fetch uses this same IP.
  return records[0].address;
}
```

**DNS rebinding defense:** we resolve the hostname **once** before the fetch, then **pin the connection to the resolved IP** by passing it as the `host` and adding the original hostname in the `Host` header. This prevents the OS from re-resolving mid-connection. (Implementation: `lookup` option on `https.Agent`.)

### 6.3 Redirects

```ts
const MAX_REDIRECTS = 3;
let redirects = 0;
let url = startUrl;
while (true) {
  const resp = await fetchOnce(url, { redirect: "manual" });
  if (resp.status >= 300 && resp.status < 400) {
    if (++redirects > MAX_REDIRECTS) throw new FetchError("too_many_redirects");
    const loc = resp.headers.get("location");
    if (!loc) throw new FetchError("redirect_without_location");
    url = new URL(loc, url).toString();
    // re-run the SSRF check on the new hostname
    await resolveAndCheck(new URL(url).hostname);
    continue;
  }
  return resp;
}
```

Each redirect hop re-runs `resolveAndCheck`. A public→private 302 is rejected.

### 6.4 Content-Type allowlist

Reject anything outside this set, **before reading the body**:

| Allowed `Content-Type` (prefix match) | Why |
|---|---|
| `text/html` | Blog posts, articles |
| `text/plain` | Plaintext docs |
| `application/xhtml+xml` | Older content |

Anything else → 400 `url_fetch_failed` with `details.reason="unsupported_content_type"`.

### 6.5 Timeouts

| Phase | Limit | Implementation |
|---|---|---|
| DNS lookup | 5s | `Promise.race` against timer |
| TCP connect | 5s | `socket.setTimeout` on the underlying Node socket |
| Total wall-clock per URL | 10s | `AbortController` |
| Total fetch budget for all URLs in a request | 25s | shared `AbortController`; 5s headroom inside the 30s overall budget |

If the per-URL or total budget trips, partial results are **discarded** — we don't pass half-fetched data to Gemini.

### 6.6 Body cap

```ts
const MAX_BODY = 5 * 1024 * 1024;  // 5MB raw bytes
let total = 0;
for await (const chunk of response.body) {
  total += chunk.length;
  if (total > MAX_BODY) {
    controller.abort();
    throw new FetchError("body_too_large");
  }
  buffer.push(chunk);
}
```

Streaming check, not `Content-Length` — servers can lie about that header.

### 6.7 User-agent

```
User-Agent: GoogleFormsCompanion-AI/1.0 (+https://<domain>/bot-info)
```

Identifies us. The `/bot-info` URL is a static page describing what the fetcher does and an email for opt-out. This is responsible-bot etiquette; it also gives us a defense if a publisher complains.

### 6.8 Per-request URL count

Already capped at **5 URLs** by the api-contract.md (`urls` minItems 1, maxItems 5). The fetcher additionally limits **concurrent** fetches to 3 within a single request to avoid burst hammering one publisher with many subdomains.

### 6.9 What gets passed to Gemini

After fetching, HTML is stripped to text (`@mozilla/readability` or `unfluff` + `sanitize-html`), then truncated to **~2500 tokens per URL** (≈10kB chars). Concatenated as the markered blocks shown in ai-prompt-spec.md §7.4.

Raw bytes are **never** persisted (per Tasks.md Task 2 acceptance: "raw uploads are never persisted").

---

## 7. PDF input safeguards

PDFs are **not parsed by us** — they're forwarded to Gemini as native `inlineData`. So the surface is just size + type.

| Check | Rule |
|---|---|
| Decoded size | ≤ 5MB (§5.3) |
| Magic bytes | First 4 bytes of decoded buffer must be `%PDF` (`0x25 0x50 0x44 0x46`) — reject base64 of arbitrary bytes |
| Encryption / passwords | We don't try; Gemini handles or fails. If Gemini errors specifically on encrypted PDF, we could surface a hint, but MVP just returns `gemini_unavailable`. |
| Persisted? | No. The base64 string is held in the request handler and discarded after the Gemini call. Only `input_size` is logged. |

Magic byte check is cheap insurance — it prevents users from base64-ing 5MB of zeros to make us pay Gemini for "PDF" tokens.

---

## 8. Cost circuit breakers

Two layers: per-user (defends one compromised account) and global (defends our wallet).

### 8.1 Per-user 24h spend

**Trigger.** Sum of `(input_tokens × $0.075/M) + (output_tokens × $0.30/M)` from `ai_generations` rows where `user_id = $u AND created_at > now() - interval '24 hours'` exceeds the cap, **including failed rows** (per Tasks.md acceptance).

**Cap.** `MAX_USER_DAILY_GEMINI_USD` env var, default **$0.50/user/24h**.

A maxed-out premium user (50 generations × ~1300 tokens each ≈ $0.014/day) sits ~35× under the cap. Trips only on grind-style abuse: ~30+ generations × ~10× expected token use, OR a high-token-budget loop. Either is suspicious.

**Action when tripped.** 503 `daily_budget_exceeded` for that user only. Log at `warn` with `user_id`, 24h spend, generation count.

**Computation cost.** One indexed query per `/ai/generate` (not per Gemini call). Index `ai_generations(user_id, created_at)` per Tasks.md Task 2 acceptance — verify it exists.

### 8.2 Global daily Gemini spend

**Trigger.** Sum of all token-derived USD from `ai_generations` where `created_at > date_trunc('day', now() AT TIME ZONE 'UTC')` exceeds `MAX_DAILY_GEMINI_SPEND_USD` (default **$10**, per Tasks.md).

**Cap behavior.** When tripped, all subsequent `/ai/generate` requests return 503 `daily_budget_exceeded`. Resets at UTC midnight (next-day window starts fresh on the read).

**Cache.** Computing this on every request is wasteful. Cached in-memory in the process for **60 seconds**, refreshed on demand. A 60s lag at the cap is acceptable — between the per-user cap (§8.1) and the rate limits (§4), the worst-case overshoot during cache lag is bounded to a few dollars.

```ts
let globalSpendCache = { value: 0, fetchedAt: 0 };
async function getGlobalDailySpendUsd(): Promise<number> {
  const now = Date.now();
  if (now - globalSpendCache.fetchedAt < 60_000) return globalSpendCache.value;
  const { rows } = await db.query(`
    SELECT
      COALESCE(SUM(input_tokens), 0)  * 0.000000075
    + COALESCE(SUM(output_tokens), 0) * 0.000000300
    AS spend_usd
    FROM ai_generations
    WHERE created_at >= date_trunc('day', now() AT TIME ZONE 'UTC')
  `);
  globalSpendCache = { value: parseFloat(rows[0].spend_usd), fetchedAt: now };
  return globalSpendCache.value;
}
```

### 8.3 Pricing constants

Hardcoded for Gemini 2.0 Flash paid tier. **Move to env when we add a second model.**

```ts
const GEMINI_INPUT_USD_PER_TOKEN  = 0.075 / 1_000_000;
const GEMINI_OUTPUT_USD_PER_TOKEN = 0.300 / 1_000_000;
```

On the free tier (1500 req/day, 15 RPM), spend is $0 — these constants over-account, which is **safe** (kill switch trips earlier than reality). When migrating to paid, no change needed.

### 8.4 What about partial Gemini calls?

Gemini bills for what it generates, even on errors. The `ai_generations` row records `input_tokens` and `output_tokens` from the Gemini response on **every** code path (success, gemini_error, validation_error). Failures **don't burn user quota** but **do count** toward circuit breakers — exactly the asymmetry Tasks.md "Quota Burn Semantics" calls for.

---

## 9. Per-user attempt rate limit (grind defense)

The `validation_error` path doesn't burn user quota (per ai-prompt-spec.md §5). Without §4's per-user 10/hour cap, an attacker could:

```
loop forever:
  POST /ai/generate { inputType: "text", prompt: "<adversarial>" }
  → Gemini call → schema fail → repair turn → schema fail → 503 validation_error
  → no quota deducted
```

Cost to attacker: ~0 (bandwidth). Cost to us: ~$0.001 per request × ∞.

§4's per-user 10/hour bounds this to ~$0.01/hour/user, ~$0.24/day/user. The 24h cost breaker (§8.1) catches the second-order case: an attacker spread across many requests of larger token consumption.

**Together, §4 + §8.1 are the answer to "validation failures don't burn quota — what stops grind attacks?"** Spelled out here so the trade-off is visible in one place.

---

## 10. Kill switches

Three switches, all read at process boot from env, applied in middleware before rate limits.

### 10.1 Env var spec

```
AI_GENERATION_DISABLED=false              # boolean
MAX_DAILY_GEMINI_SPEND_USD=10             # integer USD; 0 = no cap
USER_DENYLIST=                            # comma-separated google_sub values; empty = no denylist
HEALTH_TOKEN=<32-byte hex>                # required for /health auth
```

**Parsing rules:**

- `AI_GENERATION_DISABLED`: `true` (lower-case) → on; anything else → off. Strict to avoid `"disabled"`/`"yes"`/`"1"` ambiguity.
- `MAX_DAILY_GEMINI_SPEND_USD`: parsed as integer. `0` disables the cap. Negative or non-numeric → fail boot.
- `USER_DENYLIST`: split on `,`, trim each entry, drop empties, store as a `Set<string>` for O(1) lookup.

### 10.2 Application points

| Switch | Where in middleware | Response |
|---|---|---|
| `AI_GENERATION_DISABLED` | Before any work on `/ai/generate` | 503 `service_disabled` |
| `MAX_DAILY_GEMINI_SPEND_USD` exceeded | After auth, before quota check on `/ai/generate` | 503 `daily_budget_exceeded` |
| `USER_DENYLIST` contains user's `google_sub` | Right after auth on every authed endpoint | 403 `user_blocked` |

Order matters: the global disable runs **first** so we don't even hit the DB when the service is off. The denylist runs after auth because we need the `sub` claim.

### 10.3 Hot-reload semantics

We do **not** read env on every request — that's slow and the inconsistency window is worse than a clean reload. Instead:

```
edit /home/gfm/.env
pm2 reload gfm-api          # zero-downtime: forks new workers with new env
```

PM2 graceful reload swaps workers one at a time, no dropped requests on a small (2-vCPU) box. The reload completes in ~2s. Inflight requests on the old worker finish normally; new requests land on the new worker.

**For emergencies** where 2s is too slow, use `pm2 restart gfm-api` — drops inflight requests but is ~500ms.

### 10.4 `/health` endpoint

**Path:** `GET /health`
**Auth:** `Authorization: Bearer <HEALTH_TOKEN>` (constant-time compare to env)
**Why authed:** kill-switch state and DB connectivity are not secrets, but they're recon-useful. Token gate keeps casual scanners out without standing up an admin auth system.

**Response on 200:**

```json
{
  "status": "ok",
  "uptimeSeconds": 84321,
  "version": "0.1.0",
  "killSwitches": {
    "aiGenerationDisabled": false,
    "userDenylistCount": 0,
    "maxDailyGeminiSpendUsd": 10
  },
  "spend": {
    "todayUsd": 0.42,
    "capUsd": 10,
    "windowResetsAt": "2026-05-09T00:00:00.000Z"
  },
  "deps": {
    "postgres": { "ok": true, "latencyMs": 3 },
    "redis":    { "ok": true, "latencyMs": 1 },
    "gemini":   { "ok": true, "checkedAt": "2026-05-08T13:30:11.412Z" }
  }
}
```

**`status` values:** `"ok" | "degraded" | "down"`.
- `degraded`: a non-critical dep is unhealthy (e.g., Redis unreachable → in-memory rate limiting still works).
- `down`: critical dep unhealthy (Postgres unreachable, kill switch on).

**Failure modes:**

- Missing/invalid token → 401 `invalid_token` (same code as `/ai/generate` for consistency).
- DB unreachable when computing `spend.todayUsd` → return `null` for that field, set `status: "degraded"`.

The Gemini health check is a cached 5-minute "did our last actual call succeed" flag, **not** a synthetic call — we don't pay Gemini for health checks.

### 10.5 Runbook

| Scenario | Action | Verify |
|---|---|---|
| Gemini outage / surprise bill | `AI_GENERATION_DISABLED=true`, `pm2 reload gfm-api` | `curl -H "Authorization: Bearer $T" /health` shows `aiGenerationDisabled: true`; `/ai/generate` returns 503 `service_disabled` |
| Specific user grinding | Add `<sub>` to `USER_DENYLIST`, `pm2 reload` | User gets 403 `user_blocked`; `/health` `userDenylistCount` increments |
| Crossing the daily $ cap unexpectedly fast | Lower `MAX_DAILY_GEMINI_SPEND_USD`, `pm2 reload` | `/health` reflects new cap; once tripped, `/ai/generate` returns 503 `daily_budget_exceeded` |
| Need to revoke a denylist after fixing | Remove `<sub>` from `USER_DENYLIST`, `pm2 reload` | User can call `/ai/generate` again |
| Re-enable after `AI_GENERATION_DISABLED` | Set `AI_GENERATION_DISABLED=false`, `pm2 reload` | `/health` shows `aiGenerationDisabled: false`; smoke-test with a real `/ai/generate` |
| Whole-process recovery | `pm2 restart gfm-api` (drops inflight) — only when `reload` itself is broken | `/health` 200 |

**Verification command on the box:**

```sh
T=$(grep '^HEALTH_TOKEN=' /home/gfm/.env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://api.<domain>.com/health | jq
```

Stick this in a tmux scrollback during incidents.

---

## 11. Bot / scraper defenses

The Google ID token requirement on `/ai/generate` is the moat:

- A scraper cannot mint Google ID tokens at scale without standing up real Google accounts and signing in.
- Per-user limits + cost breakers cap the damage from any single compromised account.
- Per-IP limits cap a single scraping host even if it has many accounts.

**What we explicitly do NOT do at MVP:**

- CAPTCHA / hCaptcha — too much friction for legit users; the auth requirement already filters most scripted traffic.
- Browser fingerprinting — fragile, privacy-hostile, low signal vs. cost.
- IP reputation lookups — defer; Hostinger-default + Nginx-default handle the obvious cases.

**Where we revisit:** if logs (Task 7) show a sustained pattern of denylisted users / circuit-breaker trips from the same IP block, add Cloudflare in front and turn on Bot Fight Mode.

---

## 12. Middleware order (canonical)

Single source of truth. Express `app.use()` calls **in this order**:

```ts
// 1. Plumbing
app.use(requestId());                 // adds req.id, sets X-Request-Id header
app.use(structuredLog());             // logs request start, defers response log

// 2. Body parsing
app.use(express.json({ limit: "8mb" }));

// 3. Trusted proxy
app.set("trust proxy", "loopback");

// 4. Hard kill switches (before any work)
app.use(killSwitches.global);         // AI_GENERATION_DISABLED on /ai/* paths

// 5. Coarse limits
app.use(rateLimit.global);            // global bucket
app.use(rateLimit.perIp);             // per-IP bucket
app.use(sizeGuard);                   // belt + suspenders, body-parser already enforces

// 6. Auth (mounted per-route)
app.post("/ai/generate", auth.googleIdToken, ...);
app.get ("/user/status", auth.googleIdToken, ...);
app.post("/webhooks/revenuecat", auth.rcHmac, ...);
app.get ("/health", auth.healthToken, ...);

// 7. Per-user kill switches + limits + breakers
//    Inside each authed route handler, in this order:
//      a. denylistCheck(req.user.sub)        → 403 user_blocked
//      b. dailyBudgetCheck()                 → 503 daily_budget_exceeded  (global)
//      c. perUserBudgetCheck(req.user.id)    → 503 daily_budget_exceeded  (per-user)
//      d. rateLimit.perUserHourly(req.user.id) → 429 rate_limited
//      e. rateLimit.perUserDaily(req.user.id)  → 429 rate_limited
//      f. quotaGate(req.user.id)             → 429 quota_exceeded
//      g. business logic
```

The order in step 7 is deliberately cheapest-to-most-expensive: denylist is a `Set.has`, budget is an in-memory cached number, rate limits hit Redis, quota hits Postgres.

---

## 13. Observability hooks

Task 7 owns the metric/log spec. Hooks this doc requires Task 7 to surface:

| Signal | Source | Why |
|---|---|---|
| `rate_limit.exceeded{scope, route}` counter | rate-limit middleware | Detect abuse spikes |
| `kill_switch.tripped{which}` counter | kill-switch middleware | Audit when each switch fires |
| `cost_breaker.tripped{scope}` counter | budget middleware | Same |
| `url_fetch.blocked{reason}` counter | URL fetcher | SSRF attempts, oversized bodies, bad content-type |
| `ssrf.blocked` counter (subset of above with `reason="private_ip"`) | URL fetcher | Direct security signal |
| `gemini.spend_usd_today` gauge | budget cache | Operations dashboard |
| `health.degraded{dep}` event | /health computation | Alerting |

Suggested alert thresholds (Task 7 to refine):

- `ssrf.blocked > 5/hour` → page on-call (someone's poking).
- `rate_limit.exceeded{scope=per-user-hourly} > 20/hour from same user` → cross-reference with `cost_breaker.tripped{scope=per-user}`; consider denylist.
- `gemini.spend_usd_today` over 70% of cap → warn channel.
- `gemini.spend_usd_today` over 90% of cap → page on-call.

---

## 14. What this doc deliberately leaves open

| Question | Where it gets resolved |
|---|---|
| Exact Redis sizing (single instance OK?) | Implementation; revisit after first real load test |
| WAF / Cloudflare in front of Nginx | Defer; revisit after first 30 days of prod traffic |
| Per-route circuit breakers (Gemini specifically going down vs cost) | Task 7 (alert thresholds) |
| Auto-denylist heuristics | Manual for MVP; automation only after we have ≥30 days of denylist actions to learn from |
| RC webhook signing key rotation | Task 5 (RevenueCat webhook map) |

---

## Appendix A — Acceptance criteria mapping

| Criterion | Section |
|---|---|
| Limits specified for `/ai/generate` (per user, per IP, global) | §4.1 |
| Maximum request body size enforced at Nginx + Express | §5.1, §5.2 |
| PDF/URL fetch budgets capped (no SSRF, no recursive fetch) | §5.3, §6.2, §6.3, §7 |
| URL fetcher safeguards: blocks RFC1918 + link-local + loopback (DNS-then-IP), max 3 redirects with private-IP recheck on each hop, Content-Type allowlist, 5s connect + 10s total timeout, 5MB body cap, identifying user-agent | §6.2, §6.3, §6.4, §6.5, §6.6, §6.7 |
| Cost-per-user circuit breaker over rolling 24h, **including failed rows** | §8.1 (explicitly notes failed rows count) |
| Per-user attempt rate limit sized to bound grind-attack cost given that validation failures don't burn quota | §4.1 (10/hour, 50/day), §9 (rationale + math) |
| Kill switches `AI_GENERATION_DISABLED`, `MAX_DAILY_GEMINI_SPEND_USD`, `USER_DENYLIST` wired into config | §10.1, §10.2 |
| Kill switch state visible in `/health` (admin-only) | §10.4 |
| Runbook: how to flip each switch in production (PM2 reload vs hot reload) | §10.3, §10.5 |
