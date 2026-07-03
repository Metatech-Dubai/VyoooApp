#!/usr/bin/env node
/* eslint-disable no-console */
// Sync firestore/app_config_version_policy.json from pubspec.yaml version.
//
// Usage:
//   node scripts/sync-version-policy-from-pubspec.js [--force-update] [--dry-run]
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const dryRun = args.includes('--dry-run');
const forceUpdate = args.includes('--force-update');

const root = path.resolve(__dirname, '../..');
const pubspecPath = path.join(root, 'pubspec.yaml');
const policyPath = path.join(root, 'firestore/app_config_version_policy.json');
const examplePath = path.join(root, 'firestore/app_config_version_policy.example.json');

function parsePubspecVersion(filePath) {
  const raw = fs.readFileSync(filePath, 'utf8');
  const match = raw.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)/m);
  if (!match) {
    throw new Error(`Could not parse version from ${filePath}`);
  }
  return {
    marketing: match[1],
    build: Number.parseInt(match[2], 10),
  };
}

function loadPolicy() {
  const sourcePath = fs.existsSync(policyPath) ? policyPath : examplePath;
  if (!fs.existsSync(sourcePath)) {
    throw new Error(`Policy file not found: ${policyPath}`);
  }
  return {
    sourcePath,
    policy: JSON.parse(fs.readFileSync(sourcePath, 'utf8')),
  };
}

function applyVersion(policy, marketing, build, setMinVersion) {
  for (const platform of ['ios', 'android']) {
    if (!policy[platform] || typeof policy[platform] !== 'object') {
      policy[platform] = {};
    }
    policy[platform].latestVersion = marketing;
    policy[platform].minBuildNumber = build;
    if (setMinVersion) {
      policy[platform].minVersion = marketing;
    }
  }
  return policy;
}

function run() {
  const { marketing, build } = parsePubspecVersion(pubspecPath);
  const { sourcePath, policy } = loadPolicy();
  const before = JSON.stringify(policy, null, 2);
  applyVersion(policy, marketing, build, forceUpdate);
  const after = JSON.stringify(policy, null, 2);

  console.log(`pubspec.yaml: ${marketing}+${build}`);
  console.log(`Policy file: ${policyPath}`);
  if (forceUpdate) {
    console.log('Also setting minVersion (force update) on ios + android.');
  }

  if (before === after) {
    console.log('Policy already matches pubspec — no changes.');
    return;
  }

  if (dryRun) {
    console.log('Dry-run — would write:');
    console.log(after);
    return;
  }

  if (!fs.existsSync(policyPath) && sourcePath === examplePath) {
    console.log(`Creating ${policyPath} from example template.`);
  }

  fs.writeFileSync(policyPath, `${after}\n`, 'utf8');
  console.log(`Updated ${policyPath}`);
}

try {
  run();
} catch (err) {
  console.error('Failed:', err.message || err);
  process.exit(1);
}
