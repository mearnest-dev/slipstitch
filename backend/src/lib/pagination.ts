import { z } from "zod";

export const paginationQuery = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().int().min(1).max(50).default(20),
});

export type Pagination = z.infer<typeof paginationQuery>;

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

/**
 * Helper for cursor pagination: fetch `limit + 1`, and if the extra row exists,
 * pop it and use its id as nextCursor.
 */
export function buildPage<T extends { id: string }>(rows: T[], limit: number): Page<T> {
  if (rows.length > limit) {
    const items = rows.slice(0, limit);
    return { items, nextCursor: items[items.length - 1]!.id };
  }
  return { items: rows, nextCursor: null };
}
