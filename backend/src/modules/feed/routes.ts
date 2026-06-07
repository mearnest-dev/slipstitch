import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-feed worktree.
// Implements: GET /feed (public projects ranked recency+likes),
//   GET /search?q=&source=internal|external|both  (see docs/API.md).
// Mounts its own /feed and /search paths. External search gated behind
// env.EXTERNAL_SEARCH_ENABLED (returns empty pin set when off). Use prisma
// Project, Tag, ExternalPin; lib/pagination.ts; app.optionalAuth for `liked` state.
export const feedRoutes: FastifyPluginAsync = async (app) => {
  app.get("/feed/_stub", async () => ({ module: "feed", implemented: false }));
};
