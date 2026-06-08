import { z } from "zod";

const schema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().default(8080), // Railway's conventional port; used when PORT isn't injected
  // A Postgres connection string is not a web URL — `.url()` (new URL()) rejects
  // valid ones whose password contains chars like / + = (common in Railway's
  // generated passwords). Prisma parses it itself, so just require non-empty.
  DATABASE_URL: z.string().min(1),

  JWT_SECRET: z.string().min(16),
  ACCESS_TOKEN_TTL: z.string().default("15m"),
  REFRESH_TOKEN_TTL: z.string().default("30d"),

  APPLE_CLIENT_ID: z.string().default("com.slipstitch.app"),
  APPLE_TEAM_ID: z.string().optional(),

  R2_ACCOUNT_ID: z.string().optional(),
  R2_ACCESS_KEY_ID: z.string().optional(),
  R2_SECRET_ACCESS_KEY: z.string().optional(),
  R2_BUCKET: z.string().default("slipstitch-media"),
  R2_ENDPOINT: z.string().optional(),
  R2_PUBLIC_BASE_URL: z.string().default("https://media.slipstitch.app"),

  EXTERNAL_SEARCH_ENABLED: z
    .string()
    .default("false")
    .transform((v) => v === "true"),
});

export const env = schema.parse(process.env);
export type Env = typeof env;
