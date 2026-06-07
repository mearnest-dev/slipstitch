import fp from "fastify-plugin";
import type { FastifyReply, FastifyRequest } from "fastify";
import { verifyAccessToken } from "../lib/jwt.js";
import { unauthorized } from "../lib/errors.js";

declare module "fastify" {
  interface FastifyRequest {
    userId?: string;
    username?: string;
  }
  interface FastifyInstance {
    /** preHandler that requires a valid bearer token; sets request.userId. */
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
    /** preHandler that decodes a bearer token if present, but never rejects. */
    optionalAuth: (req: FastifyRequest, reply: FastifyReply) => Promise<void>;
  }
}

function bearer(req: FastifyRequest): string | null {
  const h = req.headers.authorization;
  if (!h || !h.startsWith("Bearer ")) return null;
  return h.slice(7);
}

export const authPlugin = fp(async (app) => {
  app.decorate("authenticate", async (req: FastifyRequest) => {
    const token = bearer(req);
    if (!token) throw unauthorized("Missing bearer token");
    try {
      const claims = await verifyAccessToken(token);
      req.userId = claims.sub;
      req.username = claims.username;
    } catch {
      throw unauthorized("Invalid or expired token", "token_invalid");
    }
  });

  app.decorate("optionalAuth", async (req: FastifyRequest) => {
    const token = bearer(req);
    if (!token) return;
    try {
      const claims = await verifyAccessToken(token);
      req.userId = claims.sub;
      req.username = claims.username;
    } catch {
      /* ignore — anonymous */
    }
  });
});
