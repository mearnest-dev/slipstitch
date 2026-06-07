import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-collections worktree.
// Implements: CRUD /collections, /collections/:id, items
//   (/collections/:id/items, supports projectId OR externalPinId)  (see docs/API.md).
// Mounted under /collections. Use prisma Collection, CollectionItem, ExternalPin.
export const collectionRoutes: FastifyPluginAsync = async (app) => {
  app.get("/_stub", async () => ({ module: "collections", implemented: false }));
};
