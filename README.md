# Stitchbook 🧶

A journaling app for crocheters. Track your projects row-by-row, photograph your
progress, build collections, and discover what other makers are creating.

- **iOS app** — native SwiftUI, pastel design system. (`/ios`)
- **API** — Node + TypeScript (Fastify + Prisma + Postgres) on Railway. (`/backend`)
- **Media** — Cloudflare R2 (S3-compatible), presigned uploads.
- **Auth** — Sign in with Apple + email/password (JWT).
- **Discovery** — internal feed of public projects now; external sources (Pinterest/web) layered in later.

## Layout

```
stitchbook/
├── backend/            # Fastify + Prisma API
│   ├── prisma/         # schema.prisma (the data contract)
│   └── src/modules/    # auth, users, projects, collections, feed, media
├── ios/                # SwiftUI app (XcodeGen project.yml)
└── docs/               # ARCHITECTURE.md, API.md, DB.md — the shared contract
```

## Develop in parallel (worktrees)

Every workstream owns a disjoint set of files so merges stay conflict-free:
- Backend `server.ts` pre-registers every module; a worktree only fills in `src/modules/<x>`.
- iOS `project.yml` globs feature folders, so new files never touch the project file.

```bash
git worktree add ../stitchbook-worktrees/auth -b feat/backend-auth
# ...build the module, commit, then merge back into main
```

## Quick start

Backend:
```bash
cd backend
npm install
cp .env.example .env   # fill in DATABASE_URL, JWT_SECRET, R2_*, APPLE_*
npx prisma migrate dev
npm run dev
```

iOS:
```bash
cd ios
xcodegen generate
open Stitchbook.xcodeproj
```
