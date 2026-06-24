#!/usr/bin/env node
/* eslint-disable no-console */
// Reconcile reels/{id}.likes with userLikes index (fixes negative / drifted counts).
//
// Auth: `firebase login` is NOT enough for this script. Use one of:
//   1) export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Downloads/vyooov1-firebase-adminsdk-....json"
//   2) gcloud auth application-default login
//   3) node scripts/reconcile-reel-likes.js --key=/path/to/adminsdk.json ...
//
// Usage:
//   node scripts/reconcile-reel-likes.js --reel-id=<id>            # dry-run one reel
//   node scripts/reconcile-reel-likes.js --reel-id=<id> --commit    # fix one reel
//   node scripts/reconcile-reel-likes.js --commit                 # fix all mismatched reels
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const pageSizeArg = args.find((arg) => arg.startsWith('--page-size='));
const pageSize = pageSizeArg ? Number(pageSizeArg.split('=')[1]) : 400;
const projectArg = args.find((arg) => arg.startsWith('--project='));
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';
const reelIdArg = args.find((arg) => arg.startsWith('--reel-id='));
const onlyReelId = reelIdArg ? reelIdArg.split('=')[1].trim() : '';
const keyArg = args.find((arg) => arg.startsWith('--key='));
const keyPath = keyArg ? keyArg.split('=').slice(1).join('=').trim() : '';

if (!Number.isFinite(pageSize) || pageSize <= 0 || pageSize > 500) {
  console.error('Invalid --page-size value. Use a number between 1 and 500.');
  process.exit(1);
}

function printAuthHelp() {
  console.error('');
  console.error('Firestore auth failed. `firebase login` does not authorize Node admin scripts.');
  console.error('Fix with ONE of:');
  console.error('  gcloud auth application-default login');
  console.error('  export GOOGLE_APPLICATION_CREDENTIALS="/path/to/vyooov1-firebase-adminsdk-....json"');
  console.error('  node scripts/reconcile-reel-likes.js --key=/path/to/adminsdk.json ...');
  console.error('');
}

function isAuthError(err) {
  const msg = String(err?.message || err || '');
  const details = String(err?.details || '');
  return (
    msg.includes('invalid_grant') ||
    msg.includes('invalid_rapt') ||
    details.includes('invalid_grant') ||
    details.includes('invalid_rapt') ||
    err?.code === 2 ||
    err?.code === 16
  );
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

const credentialPath =
  keyPath ||
  (process.env.GOOGLE_APPLICATION_CREDENTIALS || '').trim();

if (!admin.apps.length) {
  if (credentialPath) {
    if (!fs.existsSync(credentialPath)) {
      console.error(`Credential file not found: ${credentialPath}`);
      process.exit(1);
    }
    admin.initializeApp({
      credential: admin.credential.cert(credentialPath),
      projectId,
    });
  } else {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  }
}

const db = admin.firestore();

async function buildLikeCounts() {
  const counts = new Map();
  let lastDoc = null;

  while (true) {
    let query = db
      .collection('userLikes')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const reelId = String(doc.data()?.reelId || '').trim();
      if (!reelId) continue;
      counts.set(reelId, (counts.get(reelId) || 0) + 1);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  return counts;
}

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(
    shouldCommit
      ? 'Running in COMMIT mode. Firestore will be updated.'
      : 'Running in DRY-RUN mode. No documents will be changed.',
  );

  const likeCounts = await buildLikeCounts();
  console.log(`Indexed ${likeCounts.size} reel ids from userLikes.`);

  if (onlyReelId) {
    const expected = likeCounts.get(onlyReelId) || 0;
    const doc = await db.collection('reels').doc(onlyReelId).get();
    if (!doc.exists) {
      console.error(`Reel not found: ${onlyReelId}`);
      process.exit(1);
    }
    const current = Number(doc.data()?.likes);
    const stored = Number.isFinite(current) ? Math.trunc(current) : 0;
    console.log(`Reel ${onlyReelId}: stored=${stored} expected=${expected}`);
    if (stored !== expected) {
      if (shouldCommit) {
        await doc.ref.update({ likes: expected });
        console.log('Updated.');
      } else {
        console.log('Would update likes.');
      }
    } else {
      console.log('No change needed.');
    }
    return;
  }

  let lastDoc = null;
  let scanned = 0;
  let mismatched = 0;
  let updated = 0;
  let batch = db.batch();
  let batchOps = 0;

  while (true) {
    let query = db
      .collection('reels')
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);
    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned += 1;
      const raw = doc.data()?.likes;
      const stored = typeof raw === 'number' && Number.isFinite(raw) ? Math.trunc(raw) : 0;
      const expected = likeCounts.get(doc.id) || 0;
      if (stored === expected) continue;

      mismatched += 1;
      console.log(`reel ${doc.id}: stored=${stored} expected=${expected}`);

      if (shouldCommit) {
        batch.update(doc.ref, { likes: expected });
        batchOps += 1;
        if (batchOps >= 400) {
          await batch.commit();
          updated += batchOps;
          batch = db.batch();
          batchOps = 0;
        }
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  if (shouldCommit && batchOps > 0) {
    await batch.commit();
    updated += batchOps;
  }

  console.log(`Scanned ${scanned} reels.`);
  console.log(`Mismatched ${mismatched} reels.`);
  if (shouldCommit) {
    console.log(`Updated ${updated} reels.`);
  }
}

run().catch((err) => {
  if (isAuthError(err)) {
    console.error('Authentication error while talking to Firestore.');
    printAuthHelp();
    process.exit(1);
  }
  console.error(err);
  process.exit(1);
});
