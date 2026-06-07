import { SignJWT, jwtVerify } from "jose";
import crypto from "node:crypto";
import { env } from "../config/env.js";

const secret = new TextEncoder().encode(env.JWT_SECRET);

export interface AccessClaims {
  sub: string; // user id
  username: string;
}

function ttlToSeconds(ttl: string): number {
  const m = /^(\d+)([smhd])$/.exec(ttl);
  if (!m) return 900;
  const n = Number(m[1]);
  const unit = m[2];
  return n * { s: 1, m: 60, h: 3600, d: 86400 }[unit as "s" | "m" | "h" | "d"];
}

export async function signAccessToken(claims: AccessClaims): Promise<{ token: string; expiresAt: Date }> {
  const seconds = ttlToSeconds(env.ACCESS_TOKEN_TTL);
  const expiresAt = new Date(Date.now() + seconds * 1000);
  const token = await new SignJWT({ username: claims.username })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(claims.sub)
    .setIssuedAt()
    .setExpirationTime(Math.floor(expiresAt.getTime() / 1000))
    .sign(secret);
  return { token, expiresAt };
}

export async function verifyAccessToken(token: string): Promise<AccessClaims> {
  const { payload } = await jwtVerify(token, secret);
  return { sub: payload.sub as string, username: payload.username as string };
}

// Opaque refresh tokens: a random string returned to the client, only its hash is stored.
export function generateRefreshToken(): { token: string; hash: string } {
  const token = crypto.randomBytes(48).toString("base64url");
  const hash = hashRefreshToken(token);
  return { token, hash };
}

export function hashRefreshToken(token: string): string {
  return crypto.createHash("sha256").update(token).digest("hex");
}

export function refreshTokenExpiry(): Date {
  return new Date(Date.now() + ttlToSeconds(env.REFRESH_TOKEN_TTL) * 1000);
}
