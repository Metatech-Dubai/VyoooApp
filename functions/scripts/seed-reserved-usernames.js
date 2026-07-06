#!/usr/bin/env node
/* eslint-disable no-console */
// Seed Firestore reserved_usernames + app_config/username_policy.
// Admin can add/remove docs later via Firebase console or Admin SDK.
//
// Usage (replace with your actual key path):
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Downloads/vyooov1-firebase-adminsdk-....json"
//   node scripts/seed-reserved-usernames.js [--commit]
// Dry-run by default; pass --commit to write.
const fs = require('fs');
const path = require('path');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { buildReservedUsernameEntries } = require('./reserved-usernames-data');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const projectArg = args.find((arg) => arg.startsWith('--project='));
const cliProjectId = projectArg ? projectArg.split('=')[1].trim() : '';

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
  projectFromFirebaserc();

if (!projectId) {
  console.error('Project ID not found. Pass --project=<id>.');
  process.exit(1);
}

if (getApps().length === 0) {
  initializeApp({ projectId });
}

const db = getFirestore();
const BATCH_LIMIT = 450;

async function commitBatches(entries) {
  const keys = [...entries.keys()].sort();
  let written = 0;
  for (let i = 0; i < keys.length; i += BATCH_LIMIT) {
    const batch = db.batch();
    const slice = keys.slice(i, i + BATCH_LIMIT);
    for (const key of slice) {
      const meta = entries.get(key);
      const ref = db.collection('reserved_usernames').doc(key);
      batch.set(
        ref,
        {
          username: meta.username,
          category: meta.category,
          active: true,
          source: 'seed',
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await batch.commit();
    written += slice.length;
    console.log(`Committed ${written}/${keys.length} reserved_usernames docs...`);
  }
}

async function run() {
  console.log(`Using project: ${projectId}`);
  console.log(`Mode: ${shouldCommit ? 'COMMIT' : 'dry-run'}`);

  const entries = buildReservedUsernameEntries();
  console.log(`Reserved username entries to seed: ${entries.size}`);

  const policyRef = db.collection('app_config').doc('username_policy');
  const policy = {
    minLength: 4,
    maxLength: 30,
    updatedAt: FieldValue.serverTimestamp(),
  };
  console.log('username_policy:', { minLength: 4, maxLength: 30 });

  if (!shouldCommit) {
    const sample = [...entries.keys()].slice(0, 8);
    console.log('Sample reserved_usernames doc ids:', sample.join(', '));
    console.log('Dry-run complete. Re-run with --commit to apply.');
    return;
  }

  await policyRef.set(policy, { merge: true });
  console.log('Wrote app_config/username_policy');

  await commitBatches(entries);
  console.log(`Done. Seeded ${entries.size} reserved_usernames documents.`);
}

run().catch((err) => {
  console.error('Failed:', err.message || err);
  process.exit(1);
});
