# Deploying Slipstitch

## Backend → Railway

The backend ships with a `Dockerfile` and `railway.json`. Railway builds the
Docker image, runs `prisma migrate deploy` on boot, and serves on `$PORT`.

1. **Create the project & database**
   - New Railway project → add a **PostgreSQL** plugin. Railway exposes `DATABASE_URL` automatically.
   - Add a service from this repo, root directory `backend/`. It will detect `railway.json` → Dockerfile build.

2. **Environment variables** (Service → Variables) — see `backend/.env.example`:
   - `JWT_SECRET` — long random string.
   - `APPLE_CLIENT_ID` — your app bundle id / Services ID (token audience).
   - `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET`, `R2_ENDPOINT`, `R2_PUBLIC_BASE_URL`.
   - `EXTERNAL_SEARCH_ENABLED=false` (flip on once Pinterest/web ingestion lands).
   - `DATABASE_URL` is provided by the Postgres plugin — reference it with `${{Postgres.DATABASE_URL}}`.

3. **Healthcheck** — `railway.json` points at `/health` (returns `{ ok: true }`).

4. **Custom domain** — Railway → Settings → Networking → add `api.slipstitch.app`.
   In **Cloudflare** add the CNAME Railway gives you (proxied is fine). Point the
   iOS app at it via the `SLIPSTITCH_API_BASE` scheme env var or the release default in `AppConfig.swift`.

### Migrations
- A migration is committed at `backend/prisma/migrations/`. `prisma migrate deploy`
  (run automatically on boot) applies pending migrations. To add new ones locally:
  `npm run prisma:migrate -- --name <change>`.

## Media → Cloudflare R2

1. Cloudflare dashboard → R2 → create bucket `slipstitch-media`.
2. R2 → Manage API Tokens → create an **S3 Auth** token (Object Read & Write) →
   gives Access Key ID + Secret. Endpoint is `https://<account_id>.r2.cloudflarestorage.com`.
3. Serving images publicly: either enable the bucket's **public r2.dev URL** or
   (recommended) attach a Cloudflare custom domain `media.slipstitch.app` to the
   bucket and set `R2_PUBLIC_BASE_URL` to it. CORS: allow `PUT` from the app origin
   for presigned uploads (R2 → Settings → CORS).

## iOS → TestFlight / App Store

- `cd ios && xcodegen generate && open Slipstitch.xcodeproj`.
- Set `DEVELOPMENT_TEAM` in `project.yml` (or the target) to your Apple Team ID.
- **Sign in with Apple**: enable the capability for the App ID in the Apple Developer
  portal; the entitlement is already in `Slipstitch.entitlements`. Configure a
  Services ID whose identifier matches `APPLE_CLIENT_ID` on the backend.
- App icon is wired (`Assets.xcassets/AppIcon`). Archive → distribute to TestFlight.

## Local development

```bash
# Postgres (any local instance); then:
cd backend
cp .env.example .env       # fill values; DATABASE_URL to your local pg
npm install
npm run prisma:migrate     # creates tables
npm run dev                # tsx watch on :3000
# iOS simulator points at http://localhost:3000/api/v1 automatically
```
