#!/usr/bin/env bash
# mechanical-rebase.sh — L1 deterministic re-base of the pi.namespace patch
# onto an upstream release tag. Shared by CI (L1) and the L2 agent (resume).
#
# Preconditions: cwd = a git checkout of this repo with namespace-patch
# fetched; node/npm available; `npm ci` already run (stamp regen touches
# lockfiles). Conflict state (unmerged paths) is RESUMED, not restarted —
# the L2 agent resolves conflicts, then reruns this script.
#
# Usage: mechanical-rebase.sh <new-tag>       # e.g. v0.85.0
# Exit:  0 done (feature/stamp/artifacts commits on namespace-patch-next)
#        2 cherry-pick conflict (state left in the worktree for L2)
set -euo pipefail

NEW_TAG="${1:?usage: mechanical-rebase.sh <new-tag>}"
NEW_NUM="${NEW_TAG#v}"                    # 0.85.0
# Version scheme: BUILD METADATA (+namespace.N), never a prerelease tag.
# npm's arborist refuses to link a workspace package whose version is a
# prerelease when the consumer declares a caret range (^0.84.4): it installs
# the published registry version as a per-package overlay instead, whose
# stock dist layout lacks the lazy api chunks — the bundle build then fails
# with "Could not locate bundled output containing ...lazy.js". Build
# metadata is ignored by range satisfaction, so workspace links hold.
OLD_BASE="$(jq -r .baseTag patch/MANIFEST.json)"
OLD_NUM="$(jq -r .patchVersion patch/MANIFEST.json | cut -d- -f1)"
SUFFIX=1
if [ "$OLD_BASE" = "$NEW_TAG" ]; then
	SUFFIX=$(( $(jq -r .patchVersion patch/MANIFEST.json | sed -n 's/.*-namespace\.\([0-9]*\)$/\1/p') + 1 ))
fi
NEW_VER="${NEW_NUM}+namespace.${SUFFIX}"          # package version (semver build metadata)
DISPLAY_VER="${NEW_NUM}-namespace.${SUFFIX}"      # release/tag naming (URL-safe)
BRANCH="namespace-patch-next"

echo ">> rebase: ${OLD_NUM} -> ${NEW_VER} [display ${DISPLAY_VER}] (base ${NEW_TAG})"

# Runners/plain checkouts may carry no git identity; cherry-pick/commit need
# one. Local-only, does not touch global config.
if ! git config user.email >/dev/null 2>&1; then
	git config user.email "pi-namespace-pipeline@users.noreply.github.com"
	git config user.name "pi.namespace pipeline"
fi

if git ls-files --unmerged | grep -q .; then
	echo ">> conflict state detected — resuming after agent resolution"
else
	# Capture the artifact dir before switching: the release tag has no patch/
	rm -rf /tmp/patch-orig && cp -r patch /tmp/patch-orig
	FEATURE_SHA="$(jq -r .featureCommit patch/MANIFEST.json)"
	git checkout -q -B "$BRANCH" "$NEW_TAG"
	# Restore the FULL artifact dir (rules, scripts, README, apply.sh) — the
	# release tag carries none of it; only the .patch files and MANIFEST are
	# regenerated below. Restoring just MANIFEST once silently dropped the rest.
	cp -r /tmp/patch-orig/. patch/
	if ! git cherry-pick "$FEATURE_SHA"; then
		echo ">> cherry-pick conflict — leaving state for the L2 agent" >&2
		exit 2
	fi
fi
FEATURE_SHA="$(git rev-parse HEAD)"

echo ">> version stamp ${NEW_VER}"
python3 - "$OLD_NUM" "$NEW_VER" <<'PY'
import json, glob, re, sys
old, new = sys.argv[1], sys.argv[2]
pat = re.compile(r"^" + re.escape(old) + r"([+-]namespace\.\d+)?$")
n = 0
for f in sorted(glob.glob("packages/**/package.json", recursive=True)):
    if "node_modules" in f or "/examples/" in f:
        continue
    try:
        d = json.load(open(f))
    except Exception:
        continue
    v = d.get("version", "")
    if v == old or pat.match(v):
        d["version"] = new
        json.dump(d, open(f, "w"), indent="\t", ensure_ascii=False)
        open(f, "a").write("\n")
        n += 1
print(f"bumped {n} package.json files -> {new}")
PY
npm install --package-lock-only --no-audit --no-fund --registry=https://registry.npmjs.org
npm run shrinkwrap:coding-agent
npm run install-lock:coding-agent
# Guard: lock regen must never bake private-registry resolved URLs (a local
# ~/.npmrc mirror once leaked 19 nexus URLs into the root lock; CI's npm ci
# then 401s). Rewrite any non-npmjs host defensively.
python3 - <<'SCRUB'
import re, glob
for f in ["package-lock.json", "packages/coding-agent/install-lock/package-lock.json",
          "packages/coding-agent/npm-shrinkwrap.json"] + glob.glob("packages/*/package-lock.json"):
    try:
        s = open(f).read()
    except FileNotFoundError:
        continue
    s2 = re.sub(r'https://[^/"]+/repository/npm-group/', 'https://registry.npmjs.org/', s)
    s2 = re.sub(r'"resolved": "https://(?!registry\.npmjs\.org)[^/"]+/', '"resolved": "https://registry.npmjs.org/', s2)
    if s2 != s:
        open(f, "w").write(s2)
        print(f"scrubbed: {f}")
# Strip workspace overlay entries (consumer-local registry copies of
# workspace siblings) so fresh resolution re-links the workspaces. These
# appear when a previous stamp used a prerelease version (see note above)
# or when the regen ran behind a partial-registry mirror.
import json as _json, re as _re
for lf in ["package-lock.json"]:
    try:
        lock = _json.load(open(lf))
    except FileNotFoundError:
        continue
    removed = 0
    for k in list(lock["packages"].keys()):
        if _re.match(r"^packages/[^/]+/node_modules/@earendil-works/", k):
            del lock["packages"][k]
            removed += 1
    if removed:
        _json.dump(lock, open(lf, "w"), indent=2)
        print(f"stripped {removed} overlay entries from {lf}")
SCRUB
git add -A
git commit -q --no-verify -m "patch: version stamp ${DISPLAY_VER} (fork build identification)"
STAMP_SHA="$(git rev-parse HEAD)"

echo ">> artifact regeneration"
mkdir -p patch
git format-patch -1 "$FEATURE_SHA" --stdout > patch/pi-namespace.patch
git format-patch -1 "$STAMP_SHA" --stdout > patch/version-stamp.patch
python3 - "$NEW_TAG" "$FEATURE_SHA" "$STAMP_SHA" "$DISPLAY_VER" "$NEW_VER" <<'PY'
import json, sys, datetime, subprocess
new_tag, feat, stamp, display, package_ver = sys.argv[1:6]
base_sha = subprocess.run(["git", "rev-parse", new_tag], capture_output=True, text=True).stdout.strip()
m = json.load(open("patch/MANIFEST.json"))
m.update({
    "patchVersion": display,
    "packageVersion": package_ver,
    "baseTag": new_tag,
    "baseSha": base_sha,
    "featureCommit": feat,
    "versionStampCommit": stamp,
    "forkReleaseTag": f"v{display}",
    "tarballAsset": f"earendil-works-pi-coding-agent-{display}.tgz",
    "generatedAt": datetime.date.today().isoformat(),
})
json.dump(m, open("patch/MANIFEST.json", "w"), indent="\t", ensure_ascii=False)
open("patch/MANIFEST.json", "a").write("\n")
PY
git add patch
git commit -q --no-verify -m "patch: track ${NEW_TAG} (${DISPLAY_VER})" || true

echo ">> done: $(git log --oneline -3 | tr '\n' ' | ')"
