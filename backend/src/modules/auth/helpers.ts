import type { Photo, User } from "@prisma/client";
import { prisma } from "../../lib/db.js";
import {
  generateRefreshToken,
  refreshTokenExpiry,
  signAccessToken,
} from "../../lib/jwt.js";
import { serializeUser, type UserDTO } from "../users/serialize.js";

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  accessTokenExpiresAt: string;
}

export interface AuthResponse extends AuthTokens {
  user: UserDTO;
}

/** Issue + persist a fresh refresh token (only its hash is stored). */
export async function issueRefreshToken(userId: string): Promise<string> {
  const { token, hash } = generateRefreshToken();
  await prisma.refreshToken.create({
    data: { userId, tokenHash: hash, expiresAt: refreshTokenExpiry() },
  });
  return token;
}

/** Build access + refresh tokens for a user. */
export async function buildAuthTokens(user: { id: string; username: string }): Promise<AuthTokens> {
  const { token: accessToken, expiresAt } = await signAccessToken({
    sub: user.id,
    username: user.username,
  });
  const refreshToken = await issueRefreshToken(user.id);
  return {
    accessToken,
    refreshToken,
    accessTokenExpiresAt: expiresAt.toISOString(),
  };
}

/** Build a full AuthResponse (tokens + user DTO). */
export async function buildAuthResponse(
  user: User & { avatarPhoto?: Photo | null },
): Promise<AuthResponse> {
  const tokens = await buildAuthTokens(user);
  return { ...tokens, user: serializeUser(user) };
}

/** Generate a unique username from a seed (email local-part or display name). */
export async function uniqueUsername(seed: string | undefined | null): Promise<string> {
  const cleaned = (seed ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, "")
    .slice(0, 20);
  const base = cleaned.length >= 3 ? cleaned : "maker";
  // Try the base alone first, then with random suffixes until unique.
  for (let attempt = 0; attempt < 20; attempt++) {
    const candidate = attempt === 0 ? base : `${base}${Math.floor(1000 + Math.random() * 9000)}`;
    const existing = await prisma.user.findUnique({ where: { username: candidate } });
    if (!existing) return candidate;
  }
  // Extremely unlikely fallback: time-based suffix.
  return `${base}${Date.now().toString(36)}`;
}
