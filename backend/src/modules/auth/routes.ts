import type { FastifyPluginAsync } from "fastify";

// OWNED BY: feat/backend-auth worktree.
// Implements: POST /auth/email/register, /auth/email/login, /auth/apple,
//   /auth/refresh, /auth/logout  (see docs/API.md).
// Use: lib/jwt.ts (sign/verify + refresh tokens), lib/apple.ts (verifyAppleIdentityToken),
//   argon2 for password hashing, prisma User + RefreshToken models.
export const authRoutes: FastifyPluginAsync = async (app) => {
  app.get("/_stub", async () => ({ module: "auth", implemented: false }));
};
