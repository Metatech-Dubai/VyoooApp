import * as admin from 'firebase-admin';

export const USERNAME_MIN_LENGTH = 4;
export const USERNAME_MAX_LENGTH = 30;
const USERNAME_PATTERN = /^[a-zA-Z0-9_.]+$/;

export function normalizeUsername(input: unknown): string {
  return String(input ?? '')
    .trim()
    .replace(/\s/g, '');
}

export function isValidUsernameFormat(username: string): boolean {
  if (username.length < USERNAME_MIN_LENGTH || username.length > USERNAME_MAX_LENGTH) {
    return false;
  }
  if (!USERNAME_PATTERN.test(username)) return false;
  if (username.startsWith('.') || username.endsWith('.')) return false;
  if (username.includes('..')) return false;
  return true;
}

export async function readUsernameMinLength(
  db: admin.firestore.Firestore,
): Promise<number> {
  try {
    const snap = await db.collection('app_config').doc('username_policy').get();
    const min = snap.data()?.minLength;
    if (typeof min === 'number' && Number.isFinite(min) && min >= 1 && min <= 30) {
      return Math.floor(min);
    }
  } catch {
    /* use default */
  }
  return USERNAME_MIN_LENGTH;
}

export async function isReservedUsername(
  db: admin.firestore.Firestore,
  username: string,
): Promise<boolean> {
  const normalized = normalizeUsername(username);
  if (!normalized) return false;
  const key = normalized.toLowerCase();
  const snap = await db.collection('reserved_usernames').doc(key).get();
  if (!snap.exists) return false;
  const active = snap.data()?.active;
  if (typeof active === 'boolean') return active;
  return true;
}

export function usernamePolicyError(username: string, reason: string): Error {
  return new Error(`Username policy rejected "${username}": ${reason}`);
}
