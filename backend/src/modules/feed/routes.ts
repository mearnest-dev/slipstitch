import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../../lib/db.js";
import { env } from "../../config/env.js";
import { paginationQuery, type Page } from "../../lib/pagination.js";
import {
  projectSelect,
  serializeProject,
  externalPinSelect,
  serializeExternalPin,
  type ProjectDTO,
  type SearchResultDTO,
} from "./serialize.js";

// OWNED BY: feat/backend-feed worktree.
// Implements: GET /feed (public projects ranked recency+likes),
//   GET /search?q=&source=internal|external|both  (see docs/API.md).
// Mounts its own /feed and /search paths (registered WITHOUT a prefix).
// External search is gated behind env.EXTERNAL_SEARCH_ENABLED.

const searchQuery = paginationQuery.extend({
  q: z.string().trim().min(1),
  source: z.enum(["internal", "external", "both"]).default("internal"),
});

export const feedRoutes: FastifyPluginAsync = async (app) => {
  // GET /feed — public projects, recency-ranked (newest first). Cursor paginates
  // on (createdAt, id). We over-fetch by one row to derive nextCursor, and the
  // ordering secondarily reflects like volume via the _count exposed in the DTO.
  app.get(
    "/feed",
    { preHandler: app.optionalAuth },
    async (req): Promise<Page<ProjectDTO>> => {
      const { cursor, limit } = paginationQuery.parse(req.query);
      const viewerId = req.userId;

      const rows = await prisma.project.findMany({
        where: { isPublic: true },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: limit + 1,
        ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
        select: projectSelect(viewerId),
      });

      const hasMore = rows.length > limit;
      const page = hasMore ? rows.slice(0, limit) : rows;
      const items = page.map((p) => serializeProject(p, { viewerId }));
      const nextCursor = hasMore ? page[page.length - 1]!.id : null;
      return { items, nextCursor };
    },
  );

  // GET /search — q, source (internal|external|both), cursor, limit.
  app.get(
    "/search",
    { preHandler: app.optionalAuth },
    async (req): Promise<Page<SearchResultDTO>> => {
      const { q, source, cursor, limit } = searchQuery.parse(req.query);
      const viewerId = req.userId;

      const wantInternal = source === "internal" || source === "both";
      // External results are gated behind the feature flag. When the flag is off
      // we return NO external results regardless of `source`.
      //
      // NOTE: live Pinterest / web ingestion lands later. For now external
      // results are served only from the cached ExternalPin table; there is no
      // live crawl here.
      const wantExternal =
        (source === "external" || source === "both") && env.EXTERNAL_SEARCH_ENABLED;

      // Cursor encodes which stream it points into so "both" can resume cleanly:
      //   "p:<id>" for an internal project, "e:<id>" for an external pin.
      const parsed = parseCursor(cursor);

      // --- internal projects -------------------------------------------------
      let internal: SearchResultDTO[] = [];
      let internalNext: string | null = null;
      if (wantInternal) {
        const projects = await prisma.project.findMany({
          where: {
            isPublic: true,
            OR: [
              { title: { contains: q, mode: "insensitive" } },
              { yarn: { contains: q, mode: "insensitive" } },
              { craftType: { contains: q, mode: "insensitive" } },
              { tags: { some: { tag: { name: { contains: q, mode: "insensitive" } } } } },
            ],
          },
          orderBy: [{ createdAt: "desc" }, { id: "desc" }],
          take: limit + 1,
          ...(parsed.project ? { cursor: { id: parsed.project }, skip: 1 } : {}),
          select: projectSelect(viewerId),
        });
        const hasMore = projects.length > limit;
        const slice = hasMore ? projects.slice(0, limit) : projects;
        internal = slice.map((p) => ({
          kind: "project" as const,
          project: serializeProject(p, { viewerId }),
        }));
        internalNext = hasMore ? `p:${slice[slice.length - 1]!.id}` : null;
      }

      // --- external pins -----------------------------------------------------
      let external: SearchResultDTO[] = [];
      let externalNext: string | null = null;
      if (wantExternal) {
        const pins = await prisma.externalPin.findMany({
          where: {
            OR: [
              { title: { contains: q, mode: "insensitive" } },
              { sourceUrl: { contains: q, mode: "insensitive" } },
            ],
          },
          orderBy: [{ createdAt: "desc" }, { id: "desc" }],
          take: limit + 1,
          ...(parsed.pin ? { cursor: { id: parsed.pin }, skip: 1 } : {}),
          select: externalPinSelect,
        });
        const hasMore = pins.length > limit;
        const slice = hasMore ? pins.slice(0, limit) : pins;
        external = slice.map((pin) => ({
          kind: "pin" as const,
          pin: serializeExternalPin(pin),
        }));
        externalNext = hasMore ? `e:${slice[slice.length - 1]!.id}` : null;
      }

      // --- combine -----------------------------------------------------------
      let items: SearchResultDTO[];
      let nextCursor: string | null;
      if (source === "both") {
        items = interleave(internal, external).slice(0, limit);
        // Prefer continuing whichever stream still has more pages.
        nextCursor = internalNext ?? externalNext;
      } else if (source === "external") {
        items = external;
        nextCursor = externalNext;
      } else {
        items = internal;
        nextCursor = internalNext;
      }

      return { items, nextCursor };
    },
  );
};

// Cursor is "p:<id>" (project stream) or "e:<id>" (pin stream); a bare id is
// treated as a project cursor for backwards-compatibility.
function parseCursor(cursor: string | undefined): { project?: string; pin?: string } {
  if (!cursor) return {};
  if (cursor.startsWith("p:")) return { project: cursor.slice(2) };
  if (cursor.startsWith("e:")) return { pin: cursor.slice(2) };
  return { project: cursor };
}

// Round-robin merge of two result streams so "both" alternates sources.
function interleave<T>(a: T[], b: T[]): T[] {
  const out: T[] = [];
  const max = Math.max(a.length, b.length);
  for (let i = 0; i < max; i++) {
    if (i < a.length) out.push(a[i]!);
    if (i < b.length) out.push(b[i]!);
  }
  return out;
}
