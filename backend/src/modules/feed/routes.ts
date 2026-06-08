import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../../lib/db.js";
import { env } from "../../config/env.js";
import { paginationQuery, type Page } from "../../lib/pagination.js";
import { searchRavelryPatterns, ravelryConfigured, type RavelryPin } from "../../lib/ravelry.js";
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
  // GET /feed — the default Discover feed: public projects (recency) blended with
  // popular Ravelry crochet patterns when external search is enabled. Returns
  // SearchResults (project | pin) so the client renders a mixed grid. Cursor is
  // dual-stream ("p:<id>" internal, "e:<page>" Ravelry), same as /search.
  app.get(
    "/feed",
    { preHandler: app.optionalAuth },
    async (req): Promise<Page<SearchResultDTO>> => {
      const { cursor, limit } = paginationQuery.parse(req.query);
      const viewerId = req.userId;
      const parsed = parseCursor(cursor);
      const wantExternal = env.EXTERNAL_SEARCH_ENABLED && ravelryConfigured();

      // internal: public projects, newest first
      const rows = await prisma.project.findMany({
        where: { isPublic: true },
        orderBy: [{ createdAt: "desc" }, { id: "desc" }],
        take: limit + 1,
        ...(parsed.project ? { cursor: { id: parsed.project }, skip: 1 } : {}),
        select: projectSelect(viewerId),
      });
      const internalHasMore = rows.length > limit;
      const internalSlice = internalHasMore ? rows.slice(0, limit) : rows;
      const internal: SearchResultDTO[] = internalSlice.map((p) => ({
        kind: "project" as const,
        project: serializeProject(p, { viewerId }),
      }));
      const internalNext = internalHasMore
        ? `p:${internalSlice[internalSlice.length - 1]!.id}`
        : null;

      // external: popular Ravelry crochet patterns (rotating term for variety)
      let external: SearchResultDTO[] = [];
      let externalNext: string | null = null;
      if (wantExternal) {
        const page = parsed.externalPage ?? 1;
        try {
          const { items: found, hasMore } = await searchRavelryPatterns(
            feedRavelryTerm(),
            page,
            limit,
          );
          const stored = await upsertRavelryPins(found);
          external = stored.map((pin) => ({ kind: "pin" as const, pin: serializeExternalPin(pin) }));
          externalNext = hasMore ? `e:${page + 1}` : null;
        } catch (err) {
          req.log.warn({ err }, "ravelry feed fetch failed; internal-only feed");
        }
      }

      const items = wantExternal
        ? interleave(internal, external).slice(0, limit)
        : internal.slice(0, limit);
      const nextCursor = internalNext ?? externalNext;
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
      // External results come from Ravelry (live), gated behind the feature flag
      // AND configured credentials. When off, no external results are returned.
      const wantExternal =
        (source === "external" || source === "both") &&
        env.EXTERNAL_SEARCH_ENABLED &&
        ravelryConfigured();

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

      // --- external pins (live Ravelry search) -------------------------------
      // Results are upserted into ExternalPin (keyed by sourceUrl) so each has a
      // stable id and can be saved to a collection. Ravelry paginates by page;
      // the external cursor is "e:<page>". Failures degrade to no external results.
      let external: SearchResultDTO[] = [];
      let externalNext: string | null = null;
      if (wantExternal) {
        const page = parsed.externalPage ?? 1;
        try {
          const { items: found, hasMore } = await searchRavelryPatterns(q, page, limit);
          const stored = await upsertRavelryPins(found);
          external = stored.map((pin) => ({ kind: "pin" as const, pin: serializeExternalPin(pin) }));
          externalNext = hasMore ? `e:${page + 1}` : null;
        } catch (err) {
          req.log.warn({ err }, "ravelry search failed; returning no external results");
        }
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

// Cursor is "p:<id>" (project stream) or "e:<page>" (Ravelry page); a bare id is
// treated as a project cursor for backwards-compatibility.
function parseCursor(cursor: string | undefined): { project?: string; externalPage?: number } {
  if (!cursor) return {};
  if (cursor.startsWith("p:")) return { project: cursor.slice(2) };
  if (cursor.startsWith("e:")) return { externalPage: Number(cursor.slice(2)) || 1 };
  return { project: cursor };
}

// Upsert Ravelry results into ExternalPin (keyed by sourceUrl) so each has a
// stable id and is saveable to a collection. Shared by /feed and /search.
function upsertRavelryPins(pins: RavelryPin[]) {
  return Promise.all(
    pins.map((p) =>
      prisma.externalPin.upsert({
        where: { sourceUrl: p.sourceUrl },
        create: { source: "ravelry", sourceUrl: p.sourceUrl, imageUrl: p.imageUrl, title: p.title },
        update: { imageUrl: p.imageUrl, title: p.title },
        select: externalPinSelect,
      }),
    ),
  );
}

// Popular crochet terms for the default feed's external slice — rotated by the
// hour so the discovery feed stays fresh without per-request randomness.
const FEED_TERMS = [
  "amigurumi",
  "granny square",
  "crochet blanket",
  "crochet sweater",
  "crochet bag",
  "crochet hat",
  "crochet shawl",
  "crochet top",
];
function feedRavelryTerm(): string {
  return FEED_TERMS[new Date().getUTCHours() % FEED_TERMS.length]!;
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
