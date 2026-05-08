---
name: Middleware directory location
description: All Node/Express middleware code lives in gfm_mw/, not the Flutter project root
type: project
---

All middleware work (Node + Express backend, DB migrations, scripts, etc.) goes in `/Users/robi/projects/form_manager/gfm_mw/`.

**Why:** The Flutter app root is for client-side code only. The middleware is a separate service deployed to the Hostinger VPS.

**How to apply:** Never create backend/server files at the project root. Always use `gfm_mw/` as the base for any middleware deliverables (migrations, routes, scripts, config, etc.).
