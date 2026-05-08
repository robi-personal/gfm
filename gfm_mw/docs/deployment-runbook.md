# Deployment Runbook — GFM AI Middleware

**Server:** Hostinger VPS (Ubuntu 22.04)  
**Stack:** Docker Compose (app + postgres + redis + nginx), Let's Encrypt TLS

---

## First-time setup

### 1. Provision the VPS

```bash
# On the VPS — one-time setup
apt-get update && apt-get install -y docker.io docker-compose-plugin certbot python3-certbot-nginx
systemctl enable --now docker
```

### 2. Clone the repo

```bash
cd /home/gfm
git clone <repo-url> middleware
cd middleware/gfm_mw
```

### 3. Create .env

```bash
cp .env.example .env
nano .env   # fill in every CHANGE_ME value

# Generate HEALTH_TOKEN if you haven't:
echo "HEALTH_TOKEN=$(openssl rand -hex 32)" >> .env
```

**Required values to fill in:**
- `POSTGRES_PASSWORD` — strong random string
- `REDIS_PASSWORD` — strong random string
- `GOOGLE_CLIENT_ID`
- `GEMINI_API_KEY`
- `RC_WEBHOOK_SECRET` — from RevenueCat dashboard → Webhooks → Secret
- `SENTRY_DSN` — from Sentry project settings (leave blank to disable)
- `HEALTH_TOKEN` — 32+ hex bytes (use `openssl rand -hex 32`)

### 4. Obtain TLS certificate

```bash
# Point your DNS A record at the VPS IP first, then:
certbot certonly --standalone -d api.YOURDOMAIN.com

# Update nginx.prod.conf: replace YOURDOMAIN.com with your actual domain
sed -i 's/YOURDOMAIN.com/your-actual-domain.com/g' nginx/nginx.prod.conf
```

### 5. Build the production image

```bash
docker build --target runtime -t gfm-middleware:latest .
```

### 6. Run database migrations

```bash
# Start only Postgres, run migrations, then bring everything up
docker compose -f docker-compose.prod.yml up -d postgres
sleep 5
docker compose -f docker-compose.prod.yml run --rm app node dist/infrastructure/db/migrate.js
```

### 7. Start all services

```bash
docker compose -f docker-compose.prod.yml up -d
```

### 8. Verify

```bash
# Health check (replace with your actual HEALTH_TOKEN)
T=$(grep '^HEALTH_TOKEN=' .env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://api.YOURDOMAIN.com/health | jq

# Should return: { "status": "ok", "deps": { "postgres": { "ok": true }, ... } }
```

---

## Normal deployment (code update)

```bash
cd /home/gfm/middleware/gfm_mw

git pull

# Rebuild image
docker build --target runtime -t gfm-middleware:latest .

# Zero-downtime rolling restart
docker compose -f docker-compose.prod.yml up -d --no-deps app

# Verify
T=$(grep '^HEALTH_TOKEN=' .env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://api.YOURDOMAIN.com/health | jq
```

Migrations run automatically on app startup via `runMigrations()` in `server.ts`.

---

## Kill switch operations

All kill switches are env vars — change `.env`, then reload. No downtime.

### Disable AI generation (Gemini outage / surprise billing)

```bash
sed -i 's/^AI_GENERATION_DISABLED=.*/AI_GENERATION_DISABLED=true/' .env
docker compose -f docker-compose.prod.yml up -d --no-deps app

# Verify
curl -sH "Authorization: Bearer $T" https://api.YOURDOMAIN.com/health | jq '.killSwitches'
# → "aiGenerationDisabled": true
```

To re-enable: set `AI_GENERATION_DISABLED=false` and reload.

### Block a specific user

```bash
# Add google_sub to USER_DENYLIST (comma-separated if multiple)
sed -i 's/^USER_DENYLIST=.*/USER_DENYLIST=google_sub_value_here/' .env
docker compose -f docker-compose.prod.yml up -d --no-deps app
# User immediately gets 403 user_blocked
```

### Lower the daily Gemini spend cap

```bash
sed -i 's/^MAX_DAILY_GEMINI_SPEND_USD=.*/MAX_DAILY_GEMINI_SPEND_USD=5/' .env
docker compose -f docker-compose.prod.yml up -d --no-deps app
```

---

## TLS certificate renewal

Certbot auto-renews via a systemd timer installed by default. To test:

```bash
certbot renew --dry-run

# After renewal, reload nginx to pick up the new cert
docker compose -f docker-compose.prod.yml exec nginx nginx -s reload
```

Add a cron job to reload Nginx post-renewal:

```bash
echo "0 3 * * * root certbot renew --quiet && docker compose -f /home/gfm/middleware/gfm_mw/docker-compose.prod.yml exec nginx nginx -s reload" \
  > /etc/cron.d/certbot-reload
```

---

## Logs

```bash
# App logs (structured JSON)
docker compose -f docker-compose.prod.yml logs -f app | jq .

# Grep by request_id
docker compose -f docker-compose.prod.yml logs app | grep '"request_id":"<id>"' | jq .

# Grep by generation_id
docker compose -f docker-compose.prod.yml logs app | grep '"generation_id":"<uuid>"' | jq .

# Nginx access logs
docker compose -f docker-compose.prod.yml logs -f nginx
```

---

## Backups

### Postgres

```bash
# Dump to a file
docker compose -f docker-compose.prod.yml exec postgres \
  pg_dump -U $POSTGRES_USER $POSTGRES_DB | gzip > backup_$(date +%Y%m%d).sql.gz

# Restore
zcat backup_YYYYMMDD.sql.gz | docker compose -f docker-compose.prod.yml exec -T postgres \
  psql -U $POSTGRES_USER $POSTGRES_DB
```

---

## Emergency procedures

### Full restart (drops in-flight requests)

```bash
docker compose -f docker-compose.prod.yml restart app
```

### Rebuild from scratch (data preserved via volumes)

```bash
docker compose -f docker-compose.prod.yml down
docker build --target runtime -t gfm-middleware:latest .
docker compose -f docker-compose.prod.yml up -d
```

### Check Prometheus metrics

```bash
T=$(grep '^HEALTH_TOKEN=' .env | cut -d= -f2)
curl -sH "Authorization: Bearer $T" https://api.YOURDOMAIN.com/metrics | head -60
```
