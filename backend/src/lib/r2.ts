import { S3Client, GetObjectCommand, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { env } from "../config/env.js";

// Cloudflare R2 is S3-compatible. Region must be "auto".
const client = new S3Client({
  region: "auto",
  endpoint: env.R2_ENDPOINT,
  credentials: {
    accessKeyId: env.R2_ACCESS_KEY_ID ?? "",
    secretAccessKey: env.R2_SECRET_ACCESS_KEY ?? "",
  },
});

/** Presigned PUT URL the client uploads bytes directly to. */
export async function presignUpload(key: string, contentType: string, expiresIn = 600): Promise<string> {
  return getSignedUrl(
    client,
    new PutObjectCommand({ Bucket: env.R2_BUCKET, Key: key, ContentType: contentType }),
    { expiresIn },
  );
}

/** Presigned GET URL (used only for private objects; public bucket uses publicUrl). */
export async function presignDownload(key: string, expiresIn = 3600): Promise<string> {
  return getSignedUrl(client, new GetObjectCommand({ Bucket: env.R2_BUCKET, Key: key }), { expiresIn });
}

/** Public CDN URL for an object key (R2 public bucket or Cloudflare domain). */
export function publicUrl(key: string): string {
  return `${env.R2_PUBLIC_BASE_URL.replace(/\/$/, "")}/${key}`;
}
