import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-media worktree.
// Implements: POST /media/upload-url (presigned R2 PUT), POST /media/:photoId/complete,
//   GET /media/:photoId  (see docs/API.md). Mounted under /media.
// Use: lib/r2.ts (presignUpload, publicUrl); prisma Photo (uploaded flag flips on complete);
//   key convention: `users/{userId}/{photoId}.{ext}`. Validate contentType is image/*.
export const mediaRoutes: FastifyPluginAsync = async (app) => {
  app.get("/_stub", async () => ({ module: "media", implemented: false }));
};
