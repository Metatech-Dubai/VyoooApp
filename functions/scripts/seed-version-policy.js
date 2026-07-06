#!/usr/bin/env node
/* eslint-disable no-console */
// Seed Firestore app_config/version_policy for force/soft app updates.
//
// Usage:
//   export GOOGLE_APPLICATION_CREDENTIALS="$HOME/Downloads/vyooov1-firebase-adminsdk-....json"
//   node scripts/seed-version-policy.js [--commit]
//
// Dry-run by default; pass --commit to write.
const fs = require('fs');
const path = require('path');
const { initializeApp, getApps } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const args = process.argv.slice(2);
const shouldCommit = args.includes('--commit');
const projectArg = args.find((arg) => arg.startsWith('--project='));
const fileArg = args.find((arg) => arg.startsWith('--file='));
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

function policyFilePath() {
  if (fileArg) {
    const custom = fileArg.split('=').slice(1).join('=').trim();
    return path.resolve(process.cwd(), custom);
  }
  return path.resolve(__dirname, '../../firestore/app_config_version_policy.json');
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

async function run() {
  const filePath = policyFilePath();
  if (!fs.existsSync(filePath)) {
    console.error(`Policy file not found: ${filePath}`);
    process.exit(1);
  }

  const raw = fs.readFileSync(filePath, 'utf8');
  const policy = JSON.parse(raw);

  console.log(`Using project: ${projectId}`);
  console.log(`Policy file: ${filePath}`);
  console.log(`Mode: ${shouldCommit ? 'COMMIT' : 'dry-run'}`);
  console.log('version_policy payload:', JSON.stringify(policy, null, 2));

  if (!shouldCommit) {
    console.log('Dry-run complete. Re-run with --commit to apply.');
    return;
  }

  const ref = db.collection('app_config').doc('version_policy');
  await ref.set(
    {
      ...policy,
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  console.log('Wrote app_config/version_policy');
}

run().catch((err) => {
  console.error('Failed:', err.message || err);
  process.exit(1);
});
