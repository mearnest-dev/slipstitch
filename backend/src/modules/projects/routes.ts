import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-projects worktree.
// Implements: CRUD /projects, /projects/:id, progress logs (/projects/:id/logs),
//   likes (/projects/:id/like)  (see docs/API.md). Mounted under /projects.
// Use: prisma Project, ProgressLog, Like, Photo; app.authenticate / app.optionalAuth;
//   lib/pagination.ts; serialize to the Project DTO (owner: PublicUser, coverUrl, likeCount...).
export const projectRoutes: FastifyPluginAsync = async (app) => {
  app.get("/_stub", async () => ({ module: "projects", implemented: false }));
};
