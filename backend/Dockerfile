# Slipstitch API — multi-stage build for Railway.
FROM node:22-slim AS base
# OpenSSL is needed by Prisma's query engine.
RUN apt-get update -y && apt-get install -y openssl && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# --- deps ---
FROM base AS deps
COPY package.json package-lock.json* ./
RUN npm ci

# --- build ---
FROM deps AS build
COPY prisma ./prisma
RUN npx prisma generate
COPY tsconfig.json ./
COPY src ./src
RUN npm run build

# --- runtime ---
FROM base AS runtime
ENV NODE_ENV=production
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev
COPY prisma ./prisma
RUN npx prisma generate
COPY --from=build /app/dist ./dist

EXPOSE 8080
# Apply migrations on boot, then start. (Railway injects DATABASE_URL + PORT.)
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/server.js"]
