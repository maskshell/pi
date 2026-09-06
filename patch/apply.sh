#!/usr/bin/env bash
# apply.sh — build a pi.namespace-patched pi from source (tier C).
# Usage: download, then run locally:  bash apply.sh [target-dir]
# (deliberately NOT pipe-to-shell; you should read what it does)
set -euo pipefail

TARGET="${1:-pi-namespace-build}"
MANIFEST_URL_BASE="https://raw.githubusercontent.com/maskshell/pi/namespace-patch/patch"

BASE_TAG="$(curl -fsS "$MANIFEST_URL_BASE/MANIFEST.json" | jq -r .baseTag)"
echo ">> pi.namespace patch: base $BASE_TAG"

command -v git >/dev/null || { echo "git required"; exit 1; }
command -v jq >/dev/null || { echo "jq required"; exit 1; }
node --version >/dev/null 2>&1 || { echo "node >= 22.19 required"; exit 1; }

git clone --quiet https://github.com/earendil-works/pi "$TARGET"
cd "$TARGET"
git checkout --quiet "$BASE_TAG"

echo ">> applying patches (feature + version stamp)"
curl -fsS "$MANIFEST_URL_BASE/pi-namespace.patch" -o pi-namespace.patch
curl -fsS "$MANIFEST_URL_BASE/version-stamp.patch" -o version-stamp.patch
git am pi-namespace.patch version-stamp.patch

echo ">> installing deps (isolated to $TARGET)"
npm ci --no-audit --no-fund
npm run hydrate:model-data   # gitignored model data; required for check/build

echo ">> verifying"
npm run check
( cd packages/coding-agent && node ../../node_modules/vitest/dist/cli.js --run \
	test/skills.test.ts test/prompt-templates.test.ts test/resource-loader.test.ts test/package-manager.test.ts )

echo ">> building"
npm run build

echo ">> done: $TARGET (pi --version should report the namespace version)"
echo ">> install globally:  npm install -g $TARGET/packages/coding-agent"
