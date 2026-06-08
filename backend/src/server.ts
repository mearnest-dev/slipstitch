import Fastify from "fastify";
import cors from "@fastify/cors";
import { env } from "./config/env.js";
import { HttpError } from "./lib/errors.js";
import { authPlugin } from "./plugins/auth.js";

import { authRoutes } from "./modules/auth/routes.js";
import { userRoutes } from "./modules/users/routes.js";
import { projectRoutes } from "./modules/projects/routes.js";
import { collectionRoutes } from "./modules/collections/routes.js";
import { feedRoutes } from "./modules/feed/routes.js";
import { mediaRoutes } from "./modules/media/routes.js";

export async function buildServer() {
  const app = Fastify({
    logger: {
      level: env.NODE_ENV === "production" ? "info" : "debug",
      transport: env.NODE_ENV === "development" ? { target: "pino-pretty" } : undefined,
    },
  });

  await app.register(cors, { origin: true });
  await app.register(authPlugin);

  // Global error handler → { error: { code, message } }
  app.setErrorHandler((err, _req, reply) => {
    if (err instanceof HttpError) {
      return reply.status(err.statusCode).send({ error: { code: err.code, message: err.message } });
    }
    if ((err as { validation?: unknown }).validation) {
      return reply.status(400).send({ error: { code: "validation_error", message: (err as Error).message } });
    }
    reply.log.error(err);
    return reply.status(500).send({ error: { code: "internal_error", message: "Something went wrong" } });
  });

  app.get("/health", async () => ({ ok: true, service: "slipstitch", ts: new Date().toISOString() }));

  // --- API v1 ---  (each module is owned by its own worktree)
  await app.register(
    async (api) => {
      await api.register(authRoutes, { prefix: "/auth" });
      await api.register(userRoutes); // mounts /me and /users
      await api.register(projectRoutes, { prefix: "/projects" });
      await api.register(collectionRoutes, { prefix: "/collections" });
      await api.register(feedRoutes); // mounts /feed and /search
      await api.register(mediaRoutes, { prefix: "/media" });
    },
    { prefix: "/api/v1" },
  );

  return app;
}

// Entrypoint — this file is only ever executed (never imported), so always boot.
// (No `import.meta.url === file://process.argv[1]` guard: it's an ESM footgun that
// can silently evaluate false in a container, skipping listen() entirely.)
console.log(`[boot] Slipstitch API starting — NODE_ENV=${env.NODE_ENV} PORT=${env.PORT}`);
buildServer()
  // Bind "::" (dual-stack: IPv6 + IPv4) — Railway's healthcheck/private network
  // reaches the container over IPv6, so binding 0.0.0.0 (IPv4-only) fails the probe.
  .then((app) => app.listen({ port: env.PORT, host: "::" }))
  .then((addr) => console.log(`[boot] 🧶 listening at ${addr}`))
  .catch((err) => {
    console.error("[boot] FATAL — server failed to start:", err);
    process.exit(1);
  });
