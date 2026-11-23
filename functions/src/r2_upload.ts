import { createHash, randomUUID } from 'crypto';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { logger } from 'firebase-functions';
import { onDocumentCreatedWithAuthContext } from 'firebase-functions/v2/firestore';

// AWS SDK v3 signs extra checksum headers that R2 rejects on presigned PUT.
process.env.AWS_REQUEST_CHECKSUM_CALCULATION = 'WHEN_REQUIRED';
process.env.AWS_RESPONSE_CHECKSUM_VALIDATION = 'WHEN_REQUIRED';

/** Original 360 / VR masters. Phone files can be multi-gigabyte; this is the hard cap. */
const MAX_VIDEO_BYTES = 8 * 1024 * 1024 * 1024;
const MAX_THUMB_BYTES = 20 * 1024 * 1024;
const PUT_EXPIRES_SECONDS = 60 * 60;

type UploadKind = 'video' | 'thumbnail';

interface R2Config {
  accountId: string;
  accessKeyId: string;
  secretAccessKey: string;
  bucket: string;
  publicBaseUrl: string;
  endpoint: string;
}

function readConfig(): R2Config {
  const accountId = (process.env.R2_ACCOUNT_ID ?? process.env.CLOUDFLARE_ACCOUNT_ID ?? '').trim();
  const accessKeyId = (process.env.R2_ACCESS_KEY_ID ?? '').trim();
  const secretAccessKey = (process.env.R2_SECRET_ACCESS_KEY ?? '').trim();
  const bucket = (process.env.R2_BUCKET ?? '').trim();
  const publicBaseUrl = (process.env.R2_PUBLIC_BASE_URL ?? '').trim().replace(/\/+$/, '');
  const endpoint = (process.env.R2_ENDPOINT ?? '').trim().replace(/\/+$/, '');

  if (!accountId || !accessKeyId || !secretAccessKey || !bucket || !publicBaseUrl) {
    throw new Error('R2 storage is not configured.');
  }
  let parsed: URL;
  try {
    parsed = new URL(publicBaseUrl);
  } catch {
    throw new Error('R2 public URL is not configured.');
  }
  if (parsed.protocol !== 'https:') {
    throw new Error('R2 public URL must be https.');
  }
  return {
    accountId,
    accessKeyId,
    secretAccessKey,
    bucket,
    publicBaseUrl,
    endpoint: endpoint || `https://${accountId}.r2.cloudflarestorage.com`,
  };
}

function readKind(raw: unknown): UploadKind | null {
  if (raw === 'video' || raw === 'thumbnail') return raw;
  return null;
}

function readByteLength(raw: unknown, max: number): number | null {
  if (typeof raw !== 'number' || !Number.isFinite(raw)) return null;
  if (!Number.isInteger(raw) || raw <= 0 || raw > max) return null;
  return raw;
}

function publicObjectUrl(base: string, key: string): string {
  const path = key.split('/').map((part) => encodeURIComponent(part)).join('/');
  return `${base}/${path}`;
}

/**
 * Mints a one-time R2 PUT for a 360 / VR original.
 *
 * Flutter creates `r2_upload_requests/{id}` with the signed-in user id, kind,
 * content type, and byte length. The object key is chosen here. The signed URL
 * is returned on the same document and deleted by the client after upload.
 *
 * Required env: R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET, R2_PUBLIC_BASE_URL.
 * R2_ACCOUNT_ID falls back to CLOUDFLARE_ACCOUNT_ID. R2_ENDPOINT is optional.
 */
export const getR2UploadUrl = onDocumentCreatedWithAuthContext(
  {
    document: 'r2_upload_requests/{requestId}',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data() as {
      userId?: unknown;
      kind?: unknown;
      contentType?: unknown;
      contentLength?: unknown;
    };

    const userId = typeof data.userId === 'string' ? data.userId.trim() : '';
    if (!userId || event.authType === 'unauthenticated' || event.authId !== userId) {
      await snap.ref.update({ status: 'error', error: 'Unauthorized.' });
      return;
    }

    const kind = readKind(data.kind);
    const contentType = typeof data.contentType === 'string' ? data.contentType.trim().toLowerCase() : '';
    if (kind === 'video' && contentType !== 'video/mp4') {
      await snap.ref.update({ status: 'error', error: '360 video must be an MP4.' });
      return;
    }
    if (kind === 'thumbnail' && contentType !== 'image/jpeg') {
      await snap.ref.update({ status: 'error', error: 'Preview image must be a JPEG.' });
      return;
    }
    if (!kind) {
      await snap.ref.update({ status: 'error', error: 'Unsupported upload.' });
      return;
    }

    const maxBytes = kind === 'video' ? MAX_VIDEO_BYTES : MAX_THUMB_BYTES;
    const contentLength = readByteLength(data.contentLength, maxBytes);
    if (contentLength == null) {
      await snap.ref.update({ status: 'error', error: 'Upload is empty or too large.' });
      return;
    }

    try {
      const config = readConfig();
      const ext = kind === 'video' ? 'mp4' : 'jpg';
      const objectKey = `vr/${userId}/${randomUUID()}.${ext}`;
      const client = new S3Client({
        region: 'auto',
        endpoint: config.endpoint,
        forcePathStyle: true,
        credentials: {
          accessKeyId: config.accessKeyId,
          secretAccessKey: config.secretAccessKey,
        },
      });
      const command = new PutObjectCommand({
        Bucket: config.bucket,
        Key: objectKey,
        ContentType: contentType,
        ContentLength: contentLength,
      });
      const uploadUrl = await getSignedUrl(client, command, { expiresIn: PUT_EXPIRES_SECONDS });
      const publicUrl = publicObjectUrl(config.publicBaseUrl, objectKey);

      await snap.ref.update({
        status: 'done',
        uploadUrl,
        publicUrl,
        objectKey,
      });
      logger.info(
        `getR2UploadUrl ready kind=${kind} bytes=${contentLength} keyHash=${createHash('sha256').update(objectKey).digest('hex').slice(0, 12)}`,
      );
    } catch (e) {
      const message = e instanceof Error ? e.message : '';
      const safe = message.startsWith('R2 ') ? message : 'Could not prepare upload.';
      logger.error(`getR2UploadUrl failed: ${message || 'unknown'}`);
      await snap.ref.update({ status: 'error', error: safe });
    }
  },
);
