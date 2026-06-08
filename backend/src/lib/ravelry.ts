import { env } from "../config/env.js";

// Ravelry API client (read-only). Uses HTTP Basic Auth with a "read only"
// API credential pair generated in a Ravelry Pro developer app:
//   https://www.ravelry.com/pro/developer → Create an app → "Basic Auth (read only)".
// Set RAVELRY_USERNAME / RAVELRY_PASSWORD to that pair.

const RAVELRY_API = "https://api.ravelry.com";

export interface RavelryPin {
  sourceUrl: string;
  imageUrl: string;
  title: string;
}

export function ravelryConfigured(): boolean {
  return Boolean(env.RAVELRY_USERNAME && env.RAVELRY_PASSWORD);
}

function authHeader(): string {
  const creds = `${env.RAVELRY_USERNAME}:${env.RAVELRY_PASSWORD}`;
  return `Basic ${Buffer.from(creds).toString("base64")}`;
}

interface RavelryPattern {
  name?: string;
  permalink?: string;
  pattern_author?: { name?: string };
  designer?: { name?: string };
  first_photo?: Record<string, string> | null;
}

interface RavelrySearchResponse {
  patterns?: RavelryPattern[];
  paginator?: { page?: number; page_count?: number; last_page?: number };
}

/** Pick the best available photo URL (field names vary across Ravelry sizes). */
function pickPhoto(photo: Record<string, string> | null | undefined): string | null {
  if (!photo) return null;
  return (
    photo.medium_url ??
    photo.medium2_url ??
    photo.square_url ??
    photo.small2_url ??
    photo.small_url ??
    photo.thumbnail_url ??
    null
  );
}

/**
 * Search Ravelry crochet patterns. Returns pins (image + link + title) plus
 * whether more pages exist. Patterns without a photo are skipped (a pin needs
 * an image). Throws on a non-OK response so the caller can degrade gracefully.
 */
export async function searchRavelryPatterns(
  query: string,
  page: number,
  pageSize: number,
): Promise<{ items: RavelryPin[]; hasMore: boolean }> {
  const url = new URL(`${RAVELRY_API}/patterns/search.json`);
  url.searchParams.set("query", query);
  url.searchParams.set("craft", "crochet");
  url.searchParams.set("page", String(Math.max(1, page)));
  url.searchParams.set("page_size", String(pageSize));

  const res = await fetch(url, {
    headers: {
      Authorization: authHeader(),
      Accept: "application/json",
      "User-Agent": "Slipstitch/0.1 (+https://slipstitch.app)",
    },
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new Error(`Ravelry search failed (${res.status}): ${body.slice(0, 300)}`);
  }
  const data = (await res.json()) as RavelrySearchResponse;

  const items: RavelryPin[] = [];
  for (const p of data.patterns ?? []) {
    const imageUrl = pickPhoto(p.first_photo);
    if (!imageUrl || !p.permalink) continue;
    const author = p.pattern_author?.name ?? p.designer?.name;
    const name = p.name ?? "Untitled pattern";
    items.push({
      sourceUrl: `https://www.ravelry.com/patterns/library/${p.permalink}`,
      imageUrl,
      title: author ? `${name} — ${author}` : name,
    });
  }

  const pg = data.paginator;
  const hasMore =
    pg?.page != null && pg?.page_count != null
      ? pg.page < pg.page_count
      : items.length >= pageSize;

  return { items, hasMore };
}
