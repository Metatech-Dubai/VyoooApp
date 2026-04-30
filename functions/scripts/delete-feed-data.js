#!/usr/bin/env node
/* eslint-disable no-console */
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const projectArg = args.find((arg) => arg.startsWith('--project='));
const pageSizeArg = args.find((arg) => arg.startsWith('--page-size='));
const collectionsArg = args.find((arg) => arg.startsWith('--collections='));

const defaultCollections = ['reels', 'stories', 'streams', 'userLikes', 'userSaves'];
const requestedCollections = collectionsArg
  ? collectionsArg
      .split('=')[1]
      .split(',')
      .map((v) => v.trim())
      .filter(Boolean)
  : defaultCollections;

const pageSize = pageSizeArg ? Number(pageSizeArg.split('=')[1]) : 400;
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';

if (!Number.isFinite(pageSize) || pageSize <= 0 || pageSize > 500) {
  console.error('Invalid --page-size value. Use a number between 1 and 500.');
  process.exit(1);
}

if (requestedCollections.length === 0) {
  console.error('No collections provided. Use --collections=a,b,c');
  process.exit(1);
}

function projectFromFirebaserc() {
  try {
    const rcPath = path.resolve(__dirname, '../../.firebaserc');
    if (!fs.existsSync(rcPath)) return '';
    const raw = fs.readFileSync(rcPath, 'utf8');
    const parsed = JSON.parse(raw);
    return String(parsed?.projects?.default || '').trim();
  } catch (_) {
    return '';
  }
}

const projectId =
  cliProjectId ||
  process.env.GOOGLE_CLOUD_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env.FIREBASE_CONFIG_PROJECT ||
  projectFromFirebaserc();

if (!projectId) {
  console.error(
    'Project ID not found. Pass --project=<id> or set GOOGLE_CLOUD_PROJECT.',
  );
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

async function deleteCollection(collectionName) {
  let scanned = 0;
  let deleted = 0;
  let lastDoc = null;

  while (true) {
    let query = db
      .collection(collectionName)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    scanned += snap.docs.length;

    if (shouldCommit) {
      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      deleted += snap.docs.length;
      console.log(`[commit] ${collectionName}: deleted ${deleted}/${scanned}`);
    } else {
      const previewIds = snap.docs.slice(0, 5).map((d) => d.id);
      console.log(
        `[dry-run] ${collectionName}: would delete ${snap.docs.length} docs (sample ids: ${previewIds.join(', ')})`,
      );
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return {
    collectionName,
    scanned,
    deleted: shouldCommit ? deleted : 0,
  };
}

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(
    shouldCommit
      ? 'Running in COMMIT mode. Documents will be deleted.'
      : 'Running in DRY-RUN mode. No documents will be deleted.',
  );
  console.log(`Collections: ${requestedCollections.join(', ')}`);

  const results = [];
  for (const name of requestedCollections) {
    const result = await deleteCollection(name);
    results.push(result);
  }

  console.log('---');
  for (const r of results) {
    console.log(
      `${r.collectionName}: scanned=${r.scanned}, deleted=${r.deleted}`,
    );
  }
  console.log('Done.');
}

run().catch((err) => {
  console.error('Delete script failed:', err);
  process.exit(1);
});
