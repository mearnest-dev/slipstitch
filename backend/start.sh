#!/bin/sh
# Single entrypoint so migrate + server run in a real shell (Railway's
# startCommand isn't shell-wrapped, so inline "&&" silently drops the server).
set -e
echo "[start] applying migrations…"
npx prisma migrate deploy
echo "[start] launching server…"
exec node dist/server.js
