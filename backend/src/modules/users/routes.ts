import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-auth worktree (users live with auth).
// Implements: GET/PATCH /me, GET /users/:id, POST/DELETE /users/:id/follow,
//   GET /users/:id/projects  (see docs/API.md). Mounts its own /me and /users paths.
export const userRoutes: FastifyPluginAsync = async (app) => {
  app.get("/users/_stub", async () => ({ module: "users", implemented: false }));
};
