import { createRemoteJWKSet, jwtVerify } from "jose";
import { env } from "../config/env.js";
import { unauthorized } from "./errors.js";

// Apple's public keys for verifying Sign in with Apple identity tokens.
const APPLE_ISSUER = "https://appleid.apple.com";
const appleJWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));

export interface AppleIdentity {
  sub: string; // stable Apple user id
  email?: string;
  emailVerified: boolean;
}

/**
 * Verify an Apple identity token (JWT) produced by Sign in with Apple on the
 * client. Returns the verified Apple subject + email. Throws 401 on failure.
 */
export async function verifyAppleIdentityToken(identityToken: string): Promise<AppleIdentity> {
  try {
    const { payload } = await jwtVerify(identityToken, appleJWKS, {
      issuer: APPLE_ISSUER,
      audience: env.APPLE_CLIENT_ID,
    });
    return {
      sub: payload.sub as string,
      email: typeof payload.email === "string" ? payload.email : undefined,
      emailVerified: payload.email_verified === true || payload.email_verified === "true",
    };
  } catch {
    throw unauthorized("Invalid Apple identity token", "apple_token_invalid");
  }
}
