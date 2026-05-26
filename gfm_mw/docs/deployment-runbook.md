# Deployment Runbook — GFM Middleware

**Server:** Hostinger VPS (`root@177.7.51.7`, Ubuntu 22.04)
**Domain:** `gfm.robi-dev.tech` (A record in Hostinger DNS → `177.7.51.7`)
**Stack:** Docker Compose (app + postgres + redis), Nginx (host-installed) reverse-proxying `:443` → `app:3002`, Let's Encrypt TLS
**Day-to-day deploy script:** `./deploy.sh` from this directory (`gfm_mw/`)

---

## Day-to-day deploy

```bash
cd gfm_mw/
./deploy.sh
```

`deploy.sh`:
1. Validates `.env` (`POSTGRES_USER=gfm`, `POSTGRES_DB=gfm` — must match the existing data volume).
2. Builds the production image for `linux/amd64`.
3. Pipes the image to the VPS via `docker save | ssh docker load`.
4. `scp`s `docker-compose.prod.yml` and `.env` to `/root/gfm_mw/`.
5. Restarts the app container with `--no-deps --force-recreate` (postgres + redis stay warm).
6. Polls `http://localhost:3002/ping` on the VPS until 200 (up to 20s).

> **Gotcha:** `deploy.sh` overwrites the VPS `.env` with the local one. **Always update the local `.env` first** before deploying when rotating secrets (e.g. `RC_WEBHOOK_SECRET`).

Migrations run automatically on app startup via `runMigrations()` in `server.ts`.

---

## First-time VPS setup

### 1. Provision the VPS

```bash
apt-get update && apt-get install -y docker.io docker-compose-plugin certbot python3-certbot-nginx nginx
systemctl enable --now docker
mkdir -p /root/gfm_mw
```

### 2. DNS + TLS

Point the A record for `gfm.robi-dev.tech` (or your domain) at the VPS public IP, then:

```bash
certbot --nginx -d gfm.robi-dev.tech
```

Certbot auto-installs a systemd timer for renewals.

### 3. Nginx reverse proxy

Reverse-proxy `:80 / :443` to the app container's `localhost:3002`. Typical server block:

```nginx
server {
  listen 443 ssl http2;
  server_name gfm.robi-dev.tech;

  ssl_certificate     /etc/letsencrypt/live/gfm.robi-dev.tech/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/gfm.robi-dev.tech/privkey.pem;

  client_max_body_size 8m;

  location / {
    proxy_pass http://127.0.0.1:3002;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
  }
}
```

### 4. Local `.env`

Copy `gfm_mw/.env.example` to `gfm_mw/.env` and fill in every value. Required:

- `POSTGRES_PASSWORD`, `REDIS_PASSWORD` — strong random
- `GOOGLE_CLIENT_ID` (web OAuth client) + `GOOGLE_IOS_CLIENT_ID`
- `GEMINI_API_KEY` (or `OPENROUTER_API_KEY` if `AI_PROVIDER=openrouter`)
- `RC_WEBHOOK_SECRET` (RC dashboard → Webhooks → Secret)
- `RC_SECRET_API_KEY` (RC dashboard → REST API key) — used by `POST /user/purchase/sync`
- `ADMIN_TOKEN`, `ADMIN_EMAIL`, `ADMIN_PASSWORD` (`openssl rand -hex 32` for the token)
- `HEALTH_TOKEN` (`openssl rand -hex 32`)
- `SENTRY_DSN` (leave blank to disable)
- `FORMS_PUBSUB_AUDIENCE` = `https://gfm.robi-dev.tech/webhooks/forms-watch`
- `FIREBASE_SERVICE_ACCOUNT_JSON` — raw JSON or base64-encoded JSON of the Firebase service account (base64 sidesteps shell-escape issues with the private_key newlines)

### 5. First deploy

`./deploy.sh` from your laptop will push the image and bring everything up. Verify:

```bash
ssh root@177.7.51.7 'curl -s http://localhost:3002/ping'
# {"ok":true}

curl -s https://gfm.robi-dev.tech/ping
# {"ok":true}

T=$(grep '^HEALTH_TOKEN=' .env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://gfm.robi-dev.tech/health | jq
```

---

## Kill switches

All kill switches are env vars — change `.env`, then re-run `./deploy.sh` (which restarts the app with the new env). No data loss.

### Disable AI generation (provider outage / surprise billing)

```bash
sed -i '' 's/^AI_GENERATION_DISABLED=.*/AI_GENERATION_DISABLED=true/' .env
./deploy.sh
```

To re-enable: set `AI_GENERATION_DISABLED=false` and `./deploy.sh`.

### Block a specific user

```bash
sed -i '' 's/^USER_DENYLIST=.*/USER_DENYLIST=<google_sub_value>/' .env
./deploy.sh
# User immediately gets 403 user_blocked on every authenticated route.
```

Comma-separate multiple subs.

### Lower the daily Gemini spend cap

```bash
sed -i '' 's/^MAX_DAILY_GEMINI_SPEND_USD=.*/MAX_DAILY_GEMINI_SPEND_USD=5/' .env
./deploy.sh
```

### Cap a runaway user via admin UI

Use the admin SPA at `https://gfm.robi-dev.tech/admin/` — sign in with `ADMIN_EMAIL` / `ADMIN_PASSWORD`. Pages: Quota Products, Whitelist, Kill Switches, Rate Limits, YouTube, Documents (PDF pages-per-quota), Notifications (template editor).

---

## TLS renewal

Certbot's systemd timer renews automatically. To test:

```bash
ssh root@177.7.51.7 'certbot renew --dry-run'
```

After a real renewal, reload Nginx to pick up the new certificate:

```bash
ssh root@177.7.51.7 'systemctl reload nginx'
```

---

## Logs

```bash
# App logs (structured JSON via pino)
ssh root@177.7.51.7 'cd /root/gfm_mw && docker compose -f docker-compose.prod.yml logs -f --tail=200 app'

# Pipe through jq locally for readability
ssh root@177.7.51.7 'cd /root/gfm_mw && docker compose -f docker-compose.prod.yml logs --tail=500 app' | jq .

# Grep by request_id (echoed in X-Request-Id response header for client debugging)
... | jq 'select(.request_id == "<id>")'

# Grep by generation_id
... | jq 'select(.generation_id == "<uuid>")'

# Nginx access logs (host-installed Nginx, not in compose)
ssh root@177.7.51.7 'tail -f /var/log/nginx/access.log'
```

---

## Backups

```bash
ssh root@177.7.51.7 '
  cd /root/gfm_mw
  docker compose -f docker-compose.prod.yml exec -T postgres \
    pg_dump -U gfm gfm
' | gzip > backup_$(date +%Y%m%d).sql.gz

# Restore
zcat backup_YYYYMMDD.sql.gz | ssh root@177.7.51.7 '
  cd /root/gfm_mw
  docker compose -f docker-compose.prod.yml exec -T postgres psql -U gfm gfm
'
```

---

## Periodic maintenance

- `cleanup_expired_generations.sql` — purges old `ai_generations` rows past their TTL. Run manually or hook into a cron job on the VPS. (No automated scheduler yet.)

---

## Health & metrics

```bash
T=$(grep '^HEALTH_TOKEN=' .env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://gfm.robi-dev.tech/health  | jq
curl -sH "Authorization: Bearer $T" https://gfm.robi-dev.tech/metrics | head -60
```

Liveness (no auth): `curl https://gfm.robi-dev.tech/ping` → `{"ok":true}`.

---

## Emergency

### Full restart (drops in-flight)

```bash
ssh root@177.7.51.7 'cd /root/gfm_mw && docker compose -f docker-compose.prod.yml restart app'
```

### Rebuild from scratch (data preserved via volumes)

Re-run `./deploy.sh` from local. The `--force-recreate` on the app container is enough for code updates; for compose file or image-tag changes:

```bash
ssh root@177.7.51.7 'cd /root/gfm_mw && docker compose -f docker-compose.prod.yml down && docker compose -f docker-compose.prod.yml up -d'
```

> **Never** delete the postgres data volume — it holds the production user / quota / RC event tables.
