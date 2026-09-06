#!/usr/bin/env bash
# publish-npm.sh — P3 registry publication of a release tarball under the
# unscoped fork name (pi-namespace-patch).
#
# Derives a publish VARIANT from the released GitHub asset (the verified
# artifact — never rebuilt): only registry-facing metadata is rewritten
# (package name, description, repo links, shrinkwrap name keys, README
# provenance notice); code, dist, and lockfile contents stay byte-identical
# to the release.
#
# Verifies the variant before publishing: installs it from the local file
# and requires `pi --version` to report the exact stamped version. Publishes
# to registry.npmjs.org explicitly (maintainer machines may default to a
# mirror).
#
# Usage: publish-npm.sh <release-tarball.tgz> [--dry-run]
# Requires: npm auth for registry.npmjs.org (npm login --registry
#           https://registry.npmjs.org/)
set -euo pipefail

TARBALL="${1:?usage: publish-npm.sh <release-tarball.tgz> [--dry-run]}"
DRY_RUN="${2:-}"
NPM_NAME="pi-namespace-patch"
NPM_REGISTRY="https://registry.npmjs.org/"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

# Pre-flight npm's similarity rule: registering a NEW name is rejected at
# publish time if its simplified form (lowercased, -_. stripped) collides
# with an existing package (pi-ns -> pins was blocked exactly this way).
# Only relevant while the exact name is unregistered; once we own it,
# subsequent version publishes are unaffected.
SIMPLE="$(echo "$NPM_NAME" | sed 's/[-_.]//g' | tr '[:upper:]' '[:lower:]')"
if ! npm view "$NPM_NAME" name --registry="$NPM_REGISTRY" >/dev/null 2>&1; then
	if npm view "$SIMPLE" name --registry="$NPM_REGISTRY" >/dev/null 2>&1; then
		echo "!! ${NPM_NAME} is unregistrable: simplified form '${SIMPLE}' collides with an existing package (npm similarity rule)" >&2
		exit 1
	fi
fi

tar -xzf "$TARBALL" -C "$STAGE"
PKG="$STAGE/package"

python3 - "$PKG" "$NPM_NAME" <<'PY'
import json, sys
pkg_dir, name = sys.argv[1], sys.argv[2]
p = f"{pkg_dir}/package.json"
d = json.load(open(p))
old = d.get("name")
# Registry version scheme: npm enforces triple-level uniqueness (semver.eq
# ignores build metadata — "cannot publish over ... 0.85.1" blocks every
# X.Y.Z+namespace.N after the first), so the alias restamps + -> - :
# X.Y.Z-namespace.N is a distinct prerelease slot per N AND matches the
# fork's release tag string exactly. The workspace keeps the + scheme
# (arborist links); this is a leaf alias nobody ranges into a workspace.
# Safe to restamp: VERSION reads the shipped package.json at RUNTIME
# (config.ts), not a build-time bake.
ver = d.get("version", "")
npm_ver = ver.replace("+namespace.", "-namespace.") if "+namespace." in ver else ver
d["name"] = name
d["version"] = npm_ver
d["description"] = (
    d.get("description", "pi coding agent")
    + " — maskshell fork build with the pi.namespace patch (earendil-works/pi#8834)"
)
d["repository"] = {
    "type": "git",
    "url": "git+https://github.com/maskshell/pi.git",
    "directory": "packages/coding-agent",
}
d["bugs"] = {"url": "https://github.com/maskshell/pi/issues"}
d["homepage"] = "https://github.com/maskshell/pi/tree/namespace-patch/patch"
json.dump(d, open(p, "w"), indent="\t", ensure_ascii=False)
open(p, "a").write("\n")

# The shipped npm-shrinkwrap.json pins the original package name in its two
# identity keys; leave them inconsistent with package.json and installs of
# the variant would resolve against the wrong identity.
sh = f"{pkg_dir}/npm-shrinkwrap.json"
try:
    s = json.load(open(sh))
except FileNotFoundError:
    s = None
if s is not None:
    if s.get("name") == old:
        s["name"] = name
    if s.get("version") == ver:
        s["version"] = npm_ver
    root = s.get("packages", {}).get("")
    if root and root.get("name") == old:
        root["name"] = name
    if root and root.get("version") == ver:
        root["version"] = npm_ver
    # Workspace-sibling pins are landmines in a PUBLISHED package: the
    # stamp puts them at <X.Y.Z>+namespace.N — versions that exist only in
    # the fork workspace, never on the registry — so registry installs 404
    # on their resolved tarballs (file/URL installs re-resolve via ranges
    # and mask this). Delete the pins; the caret ranges in package.json
    # then resolve to the published upstream base versions, which are
    # byte-equivalent for siblings (the patch touches only coding-agent).
    dropped = [k for k in s.get("packages", {}) if k.startswith("node_modules/@earendil-works/")]
    for k in dropped:
        del s["packages"][k]
    json.dump(s, open(sh, "w"), indent="\t", ensure_ascii=False)
    open(sh, "a").write("\n")
    if dropped:
        print(f"dropped {len(dropped)} workspace-sibling pins from the variant shrinkwrap")
PY

README="$PKG/README.md"
if [ -f "$README" ]; then
	printf '<!-- pi-namespace-patch is the maskshell fork build of pi carrying the pi.namespace patch (earendil-works/pi#8834). Upstream project: earendil-works/pi. Fork source + release-tracked patches: https://github.com/maskshell/pi (namespace-patch branch). This README below is upstream'"'"'s. -->\n\n' | cat - "$README" > "$README.new" && mv "$README.new" "$README"
fi

VERSION="$(python3 -c "import json; print(json.load(open('$PKG/package.json'))['version'])")"

# Guard: after sibling-pin removal, no non-root shrinkwrap entry may carry a
# stamped +namespace version — that is exactly the 404-on-install landmine.
python3 - "$PKG/npm-shrinkwrap.json" <<'PY'
import json, sys
try:
    s = json.load(open(sys.argv[1]))
except FileNotFoundError:
    sys.exit(0)
bad = [k for k, v in (s.get("packages") or {}).items() if k and "+namespace." in str(v.get("version", ""))]
if bad:
    print(f"!! variant shrinkwrap still pins stamped versions at: {bad}"[:500], file=sys.stderr)
    sys.exit(1)
PY
OUT="$STAGE/out"; mkdir -p "$OUT"
( cd "$PKG" && npm pack --pack-destination "$OUT" ) >/dev/null
VARIANT="$OUT/${NPM_NAME}-${VERSION}.tgz"
echo ">> variant: ${NPM_NAME}@${VERSION} ($(du -h "$VARIANT" | cut -f1))"

echo ">> pre-publish verification: install variant from file, check pi --version"
VDIR="$STAGE/verify"; mkdir -p "$VDIR"
( cd "$VDIR" && npm install --no-audit --no-fund --registry="$NPM_REGISTRY" "$VARIANT" >/dev/null 2>&1 )
GOT="$("$VDIR/node_modules/.bin/pi" --version)"
if [ "$GOT" != "$VERSION" ]; then
	echo "!! pi --version reported '${GOT}', expected '${VERSION}' — aborting" >&2
	exit 1
fi
echo ">> pi --version -> ${GOT}"

# --tag latest: prerelease versions (X.Y.Z-namespace.N) must declare their
# dist-tag explicitly; latest is the intent for this alias either way.
# --provenance when running under GitHub Actions OIDC (trusted publishing):
# free supply-chain attestation there, impossible from a local publish.
PROVENANCE=""
if [ -n "${GITHUB_ACTIONS:-}" ] && [ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ]; then
	PROVENANCE="--provenance"
fi
# Explicit --registry is for maintainer machines (a mirror default must
# not receive a publish). In GitHub Actions the default registry IS
# npmjs — and npm's trusted-publishing (OIDC) short-circuit only engages
# for the default registry; an explicit flag bypasses it (ENEEDAUTH).
REG_FLAG=("--registry=$NPM_REGISTRY")
if [ -n "${GITHUB_ACTIONS:-}" ]; then
	REG_FLAG=()
fi
npm publish "${REG_FLAG[@]}" --tag latest $PROVENANCE ${DRY_RUN:+--dry-run} "$VARIANT"
echo ">> publish ${DRY_RUN:+(dry-run) }done: ${NPM_NAME}@${VERSION}"

if [ -n "$DRY_RUN" ]; then
	exit 0
fi

# Post-publish registry verification — the file-install path cannot catch a
# broken shrinkwrap (npm re-resolves deps from ranges); only a registry
# install exercises it. Retry briefly: read replicas lag on fresh publishes.
echo ">> registry verification: install ${NPM_NAME}@${VERSION} from npmjs"
RDIR="$STAGE/registry-verify"
i=0
until mkdir "$RDIR" 2>/dev/null; do RDIR="$RDIR-$i"; i=$((i+1)); done
ok=0
for attempt in 1 2 3 4 5; do
	if ( cd "$RDIR" && npm install --no-audit --no-fund --registry="$NPM_REGISTRY" "${NPM_NAME}@${VERSION}" >/dev/null 2>&1 ); then ok=1; break; fi
	echo "   attempt $attempt failed (propagation lag?) — retrying in 20s"; sleep 20
done
if [ "$ok" != 1 ]; then
	echo "!! REGISTRY INSTALL FAILED for ${NPM_NAME}@${VERSION} — do not announce; investigate" >&2
	exit 1
fi
GOT="$($RDIR/node_modules/.bin/pi --version)"
[ "$GOT" = "$VERSION" ] || { echo "!! registry pi --version reported '$GOT', expected '$VERSION'" >&2; exit 1; }
echo ">> registry install green: pi --version -> ${GOT}"
