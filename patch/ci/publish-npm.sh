#!/usr/bin/env bash
# publish-npm.sh — P3 registry publication of a release tarball under the
# unscoped fork name (pi-ns).
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
NPM_NAME="pi-ns"
NPM_REGISTRY="https://registry.npmjs.org/"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

tar -xzf "$TARBALL" -C "$STAGE"
PKG="$STAGE/package"

python3 - "$PKG" "$NPM_NAME" <<'PY'
import json, sys
pkg_dir, name = sys.argv[1], sys.argv[2]
p = f"{pkg_dir}/package.json"
d = json.load(open(p))
old = d.get("name")
d["name"] = name
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
    root = s.get("packages", {}).get("")
    if root and root.get("name") == old:
        root["name"] = name
    json.dump(s, open(sh, "w"), indent="\t", ensure_ascii=False)
    open(sh, "a").write("\n")
PY

README="$PKG/README.md"
if [ -f "$README" ]; then
	printf '<!-- pi-ns is the maskshell fork build of pi carrying the pi.namespace patch (earendil-works/pi#8834). Upstream project: earendil-works/pi. Fork source + release-tracked patches: https://github.com/maskshell/pi (namespace-patch branch). This README below is upstream'"'"'s. -->\n\n' | cat - "$README" > "$README.new" && mv "$README.new" "$README"
fi

VERSION="$(python3 -c "import json; print(json.load(open('$PKG/package.json'))['version'])")"
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

npm publish --registry="$NPM_REGISTRY" ${DRY_RUN:+--dry-run} "$VARIANT"
echo ">> publish ${DRY_RUN:+(dry-run) }done: ${NPM_NAME}@${VERSION}"
