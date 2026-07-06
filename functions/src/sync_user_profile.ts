import * as admin from 'firebase-admin';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';

const BATCH_LIMIT = 450;
const CHAT_PAGE_SIZE = 150;
const NOTIF_PAGE_SIZE = 400;

function trimText(value: unknown): string {
  return typeof value === 'string' ? value.trim() : '';
}

function inboxTitle(displayName: string, username: string): string {
  if (displayName) return displayName;
  return username;
}

function actorLabel(username: string, displayName: string): string {
  if (username) return username;
  if (displayName) return displayName;
  return 'Someone';
}

/**
 * When a user updates username, display name, or avatar, fan out to denormalized
 * chat participant maps, direct-chat inbox summaries, and notification actor fields.
 */
export const syncUserProfileDenormalized = onDocumentWritten(
  {
    document: 'users/{userId}',
    timeoutSeconds: 120,
    memory: '512MiB',
  },
  async (event) => {
    const userId = event.params.userId;
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Skip creates/deletes; only profile edits on existing accounts.
    if (!before || !after) return;

    const oldUsername = trimText(before.username);
    const newUsername = trimText(after.username);
    const oldDisplayName = trimText(before.displayName);
    const newDisplayName = trimText(after.displayName);
    const oldAvatar = trimText(before.profileImage);
    const newAvatar = trimText(after.profileImage);

    if (
      oldUsername === newUsername &&
      oldDisplayName === newDisplayName &&
      oldAvatar === newAvatar
    ) {
      return;
    }

    const db = admin.firestore();
    const summaryTitle = inboxTitle(newDisplayName, newUsername);
    const actorUsername = actorLabel(newUsername, newDisplayName);

    let chatsUpdated = 0;
    let summariesUpdated = 0;
    let notificationsUpdated = 0;

    let lastChatDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = db
        .collection('chats')
        .where('participantIds', 'array-contains', userId)
        .limit(CHAT_PAGE_SIZE);
      if (lastChatDoc) {
        query = query.startAfter(lastChatDoc);
      }

      const chatSnap = await query.get();
      if (chatSnap.empty) break;

      let batch = db.batch();
      let batchOps = 0;

      const flushBatch = async () => {
        if (batchOps === 0) return;
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      };

      for (const chatDoc of chatSnap.docs) {
        const chatData = chatDoc.data() as Record<string, unknown>;
        const chatId = chatDoc.id;
        const chatType = trimText(chatData.type) || 'direct';
        const participantIds = Array.isArray(chatData.participantIds)
          ? chatData.participantIds.filter(
              (v): v is string => typeof v === 'string' && v.length > 0,
            )
          : [];

        const participantMap = chatData.participantMap as
          | Record<string, Record<string, unknown>>
          | undefined;
        const existing = participantMap?.[userId];
        const role =
          typeof existing?.role === 'string' && existing.role.trim()
            ? existing.role.trim()
            : 'member';

        batch.update(chatDoc.ref, {
          [`participantMap.${userId}`]: {
            uid: userId,
            displayName: newDisplayName,
            username: newUsername,
            avatarUrl: newAvatar,
            role,
          },
        });
        batchOps += 1;
        chatsUpdated += 1;

        if (chatType === 'direct' && participantIds.length === 2) {
          const otherUid = participantIds.find((id) => id !== userId);
          if (otherUid) {
            batch.set(
              db
                .collection('users')
                .doc(otherUid)
                .collection('chatSummaries')
                .doc(chatId),
              { title: summaryTitle, avatarUrl: newAvatar },
              { merge: true },
            );
            batchOps += 1;
            summariesUpdated += 1;
          }
        }

        if (batchOps >= BATCH_LIMIT) {
          await flushBatch();
        }
      }

      await flushBatch();

      if (chatSnap.size < CHAT_PAGE_SIZE) break;
      lastChatDoc = chatSnap.docs[chatSnap.docs.length - 1];
    }

    let lastNotifDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;
    for (;;) {
      let query = db
        .collection('notifications')
        .where('senderId', '==', userId)
        .limit(NOTIF_PAGE_SIZE);
      if (lastNotifDoc) {
        query = query.startAfter(lastNotifDoc);
      }

      const notifSnap = await query.get();
      if (notifSnap.empty) break;

      let batch = db.batch();
      let batchOps = 0;

      const flushBatch = async () => {
        if (batchOps === 0) return;
        await batch.commit();
        batch = db.batch();
        batchOps = 0;
      };

      for (const notifDoc of notifSnap.docs) {
        batch.update(notifDoc.ref, {
          actorUsername,
          actorAvatarUrl: newAvatar,
        });
        batchOps += 1;
        notificationsUpdated += 1;
        if (batchOps >= BATCH_LIMIT) {
          await flushBatch();
        }
      }

      await flushBatch();

      if (notifSnap.size < NOTIF_PAGE_SIZE) break;
      lastNotifDoc = notifSnap.docs[notifSnap.docs.length - 1];
    }

    logger.info('syncUserProfileDenormalized: done', {
      userId,
      chatsUpdated,
      summariesUpdated,
      notificationsUpdated,
      usernameChanged: oldUsername !== newUsername,
      displayNameChanged: oldDisplayName !== newDisplayName,
      avatarChanged: oldAvatar !== newAvatar,
    });
  },
);
