import type { FastifyPluginAsync } from "fastify";
import argon2 from "argon2";
import { z } from "zod";
import { prisma } from "../../lib/db.js";
import { hashRefreshToken } from "../../lib/jwt.js";
import { verifyAppleIdentityToken } from "../../lib/apple.js";
import { badRequest, conflict, unauthorized } from "../../lib/errors.js";
import {
  buildAuthResponse,
  buildAuthTokens,
  uniqueUsername,
} from "./helpers.js";

// OWNED BY: feat/backend-auth worktree.
// Implements: POST /auth/email/register, /auth/email/login, /auth/apple,
//   /auth/refresh, /auth/logout  (see docs/API.md).

const registerSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8).max(200),
  username: z
    .string()
    .min(3)
    .max(30)
    .regex(/^[a-zA-Z0-9_]+$/, "username may only contain letters, numbers, and underscores"),
  displayName: z.string().min(1).max(80),
});

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const appleSchema = z.object({
  identityToken: z.string().min(1),
  nonce: z.string().min(1),
  fullName: z.string().min(1).max(80).optional(),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

function parse<T>(schema: z.ZodSchema<T>, body: unknown): T {
  const result = schema.safeParse(body);
  if (!result.success) {
    const first = result.error.issues[0];
    throw badRequest(first ? `${first.path.join(".")}: ${first.message}` : "Invalid request body");
  }
  return result.data;
}

export const authRoutes: FastifyPluginAsync = async (app) => {
  // POST /auth/email/register
  app.post("/email/register", async (req, reply) => {
    const { email, password, username, displayName } = parse(registerSchema, req.body);
    const normalizedEmail = email.toLowerCase();

    const existing = await prisma.user.findFirst({
      where: { OR: [{ email: normalizedEmail }, { username }] },
      select: { email: true, username: true },
    });
    if (existing) {
      if (existing.email === normalizedEmail) throw conflict("Email already in use", "email_taken");
      throw conflict("Username already taken", "username_taken");
    }

    const passwordHash = await argon2.hash(password);
    const user = await prisma.user.create({
      data: { email: normalizedEmail, passwordHash, username, displayName },
      include: { avatarPhoto: true },
    });

    reply.status(201);
    return buildAuthResponse(user);
  });

  // POST /auth/email/login
  app.post("/email/login", async (req) => {
    const { email, password } = parse(loginSchema, req.body);
    const user = await prisma.user.findUnique({
      where: { email: email.toLowerCase() },
      include: { avatarPhoto: true },
    });
    if (!user || !user.passwordHash) {
      throw unauthorized("Invalid email or password", "invalid_credentials");
    }
    const ok = await argon2.verify(user.passwordHash, password);
    if (!ok) throw unauthorized("Invalid email or password", "invalid_credentials");

    return buildAuthResponse(user);
  });

  // POST /auth/apple
  app.post("/apple", async (req) => {
    const { identityToken, fullName } = parse(appleSchema, req.body);
    const identity = await verifyAppleIdentityToken(identityToken);

    let user = await prisma.user.findUnique({
      where: { appleSub: identity.sub },
      include: { avatarPhoto: true },
    });

    if (!user) {
      // New Apple user: link by email if one already exists, else create.
      if (identity.email) {
        const byEmail = await prisma.user.findUnique({
          where: { email: identity.email.toLowerCase() },
          include: { avatarPhoto: true },
        });
        if (byEmail) {
          user = await prisma.user.update({
            where: { id: byEmail.id },
            data: { appleSub: identity.sub },
            include: { avatarPhoto: true },
          });
        }
      }

      if (!user) {
        const seed = identity.email ? identity.email.split("@")[0] : fullName;
        const username = await uniqueUsername(seed);
        user = await prisma.user.create({
          data: {
            appleSub: identity.sub,
            email: identity.email ? identity.email.toLowerCase() : null,
            username,
            displayName: fullName ?? username,
          },
          include: { avatarPhoto: true },
        });
      }
    }

    return buildAuthResponse(user);
  });

  // POST /auth/refresh — rotate the refresh token.
  app.post("/refresh", async (req) => {
    const { refreshToken } = parse(refreshSchema, req.body);
    const tokenHash = hashRefreshToken(refreshToken);

    const stored = await prisma.refreshToken.findUnique({ where: { tokenHash } });
    if (!stored || stored.revokedAt || stored.expiresAt.getTime() <= Date.now()) {
      throw unauthorized("Invalid or expired refresh token", "refresh_token_invalid");
    }

    const user = await prisma.user.findUnique({ where: { id: stored.userId } });
    if (!user) throw unauthorized("Invalid or expired refresh token", "refresh_token_invalid");

    // Rotate: revoke the old token, issue a fresh pair.
    await prisma.refreshToken.update({
      where: { tokenHash },
      data: { revokedAt: new Date() },
    });

    return buildAuthTokens(user);
  });

  // POST /auth/logout — revoke the supplied refresh token.
  app.post("/logout", async (req, reply) => {
    const { refreshToken } = parse(refreshSchema, req.body);
    const tokenHash = hashRefreshToken(refreshToken);
    await prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    reply.status(204);
    return null;
  });
};
