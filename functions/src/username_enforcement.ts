import { onDocumentWrittenWithAuthContext } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import * as admin from 'firebase-admin';
import {
  isReservedUsername,
  isValidUsernameFormat,
  normalizeUsername,
  readUsernameMinLength,
  USERNAME_MAX_LENGTH,
} from './username_policy';

function usernameChanged(
  before: admin.firestore.DocumentData | undefined,
  after: admin.firestore.DocumentData | undefined,
): boolean {
  const oldName = normalizeUsername(before?.username);
  const newName = normalizeUsername(after?.username);
  return oldName !== newName;
}

function tempUsernameFor(userId: string): string {
  const cleaned = userId.replace(/[^a-zA-Z0-9]/g, '');
  const tail =
    cleaned.length >= 8 ? cleaned.slice(cleaned.length - 8) : cleaned.padStart(8, '0');
  return normalizeUsername(`user_${tail}`);
}

function isPrivilegedWrite(authType: string, authId: string | undefined, userId: string): boolean {
  if (authType === 'system' || authType === 'service_account') {
    return true;
  }
  if (!authId || authId !== userId) {
    return true;
  }
  return false;
}

async function usernameViolatesPolicy(
  db: admin.firestore.Firestore,
  username: string,
): Promise<string | null> {
  const minLength = await readUsernameMinLength(db);
  if (username.length < minLength || username.length > USERNAME_MAX_LENGTH) {
    return `must be ${minLength}-${USERNAME_MAX_LENGTH} characters`;
  }
  if (!isValidUsernameFormat(username)) {
    return 'invalid format';
  }
  if (await isReservedUsername(db, username)) {
    return 'reserved';
  }
  return null;
}

/**
 * Reverts invalid/reserved usernames set by the account owner via the client SDK.
 * Admin/dashboard writes (Admin SDK or non-owner) are not reverted.
 */
export const enforceUserUsernamePolicy = onDocumentWrittenWithAuthContext(
  'users/{userId}',
  async (event) => {
    const userId = event.params.userId;
    if (isPrivilegedWrite(event.authType, event.authId, userId)) {
      return;
    }

    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!after) return;

    if (!usernameChanged(before, after)) return;

    const username = normalizeUsername(after.username);
    if (!username) return;

    const db = admin.firestore();
    const violation = await usernameViolatesPolicy(db, username);
    if (!violation) return;

    const previous = normalizeUsername(before?.username);
    let fallback = previous;
    if (!fallback || (await usernameViolatesPolicy(db, fallback)) !== null) {
      fallback = tempUsernameFor(userId);
    }

    logger.warn('enforceUserUsernamePolicy: reverting username', {
      userId,
      attempted: username,
      fallback,
      violation,
    });

    await event.data!.after!.ref.update({ username: fallback });
  },
);
