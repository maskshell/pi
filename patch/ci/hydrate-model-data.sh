#!/usr/bin/env bash
# hydrate-model-data.sh — materialize the gitignored provider catalog for the
# CURRENT worktree, preferring the release's pinned catalog revision
# (nix/model-catalog.json).
#
# Why the pin: tsgo type-checks the release's tests against the exact model IDs
# that release shipped with (`getModel("xiaomi", "mimo-v2.5-pro")` etc.), while
# a live models.dev fetch drifts underneath (2026-10-16: xiaomi stopped
# advertising mimo-v2.5-pro, so a live hydrate reds npm-check against the
# unchanged v1.3.0 tests). Upstream's Nix build hydrates from the same pinned
# revision; `npm run build` regenerates live data, so verify.sh must re-hydrate
# from the pin before its gates.
#
# Best-effort by design: if the pin cannot be fetched or hydrated, fall back to
# live models.dev so a network/pin problem degrades to the old behavior rather
# than a hard failure. The gates surface the real state.
#
# Usage: hydrate-model-data.sh [repo-root]
set -uo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel)}"
cd "$ROOT" || exit 1

rev="$(jq -r '.revision // empty' nix/model-catalog.json 2>/dev/null)"
if [ -n "$rev" ]; then
	tmp="$(mktemp)"
	trap 'rm -f "$tmp"' EXIT
	if curl -fsS --max-time 180 \
		"https://pi.dev/api/models/revisions/${rev}?types=chat,image,classifier" -o "$tmp" \
		&& [ "$(printf 'sha256-%s' "$(sha256sum "$tmp" | cut -d' ' -f1)")" = "$rev" ] \
		&& node packages/ai/scripts/hydrate-model-catalog.ts "$tmp"; then
		echo ">> hydrated provider catalog from pinned revision ${rev}"
		exit 0
	fi
	echo ">> WARN: pinned catalog ${rev} unavailable; falling back to live models.dev" >&2
fi

npm run hydrate:model-data
