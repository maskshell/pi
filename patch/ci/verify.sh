#!/usr/bin/env bash
# verify.sh — release gates for the pi.namespace patch, run on the CURRENT
# worktree (post mechanical-rebase or post L2 repair). cwd-agnostic.
# Exit 0 = all gates green; failing gate names land in gate-results.txt.
set -uo pipefail

ROOT="$(git rev-parse --show-toplevel)"
PKG="$ROOT/packages/coding-agent"

# npm run check (tsgo) and the touched suites import the generated provider
# catalog, which is gitignored and absent on a fresh runner checkout. L1's
# mechanical rebase hydrates it, but a resumed/partial run can leave it
# missing; materialize it before the gates so a failure here is a real
# regression, not a missing-data artifact. Best-effort by design.
if [ ! -f "$ROOT/packages/ai/src/providers/data/.manifest.json" ]; then
	if ! (cd "$ROOT" && npm run hydrate:model-data); then
		echo ">> WARN: hydrate:model-data failed; npm-check/suites import the generated catalog" >&2
	fi
fi

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
