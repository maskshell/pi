#!/usr/bin/env bash
# verify.sh — release gates for the pi.namespace patch, run on the CURRENT
# worktree (post mechanical-rebase or post L2 repair). cwd-agnostic.
# Exit 0 = all gates green; failing gate names land in gate-results.txt.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PKG="$ROOT/packages/coding-agent"

# npm run check (tsgo) and the touched suites import the generated provider
# catalog, which is gitignored. Hydrate it from the release's pinned catalog
# revision before the gates: a live models.dev fetch drifts and type-checks the
# release's tests against model IDs that no longer exist (see
# hydrate-model-data.sh). Unconditional because `npm run build` regenerates
# live data, so a previous verify run leaves the catalog drifted. Best-effort
# by design: a failed hydration lets the gates report the real regression.
bash "$(dirname "$0")/hydrate-model-data.sh" "$ROOT" || \
	echo ">> WARN: model data hydration failed; npm-check/suites import the generated catalog" >&2

run_gate() {
	local name="$1"; shift
	echo "=== gate: ${name} ==="
	if ! "$@"; then
		echo "GATE_FAILED=${name}" >> "$ROOT/gate-results.txt"
		echo ">> gate FAILED: ${name}" >&2
		return 1
	fi
	echo "GATE_OK=${name}" >> "$ROOT/gate-results.txt"
}

rm -f "$ROOT/gate-results.txt"

run_gate npm-check bash -c "cd '$ROOT' && npm run check" || FAILED=1
run_gate suites bash -c "cd '$PKG' && node '$ROOT/node_modules/vitest/dist/cli.js' --run \
	test/skills.test.ts test/prompt-templates.test.ts \
	test/resource-loader.test.ts test/package-manager.test.ts \
	test/version-check.test.ts" || FAILED=1
run_gate build bash -c "cd '$ROOT' && npm run build" || FAILED=1
run_gate lockfiles-public bash -c "! grep -rE '\"resolved\": \"https://(?!registry\\.npmjs\\.org)' \
	'$ROOT/package-lock.json' '$ROOT/packages/coding-agent/npm-shrinkwrap.json' \
	'$ROOT/packages/coding-agent/install-lock/package-lock.json' 2>/dev/null" || FAILED=1

if [ -n "${FAILED:-}" ]; then
	echo ">> verification failed:"; cat "$ROOT/gate-results.txt"
	exit 1
fi
echo ">> all gates green"; cat "$ROOT/gate-results.txt"
