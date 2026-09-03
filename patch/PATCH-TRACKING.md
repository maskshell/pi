# PATCH-TRACKING — pi.namespace patch lifecycle rules

Authoritative procedure for keeping the `pi.namespace` patch aligned with
upstream earendil-works/pi releases. Until an automated harness exists, every
step marked **[harness]** is executed manually by the maintainer/agent working
in this fork; the only automated step is the release monitor.

## Roles

- **Upstream**: earendil-works/pi (releases `vX.Y.Z`).
- **Fork**: maskshell/pi. `main` mirrors upstream main (sole fork-specific
  file: `.github/workflows/namespace-patch-tracker.yml`). The patch lives on
  `namespace-patch` as: [1] feature commit, [2] version-stamp commit,
  [3] `patch/` artifact directory (patches, MANIFEST, README, apply.sh, this
  file). `package-namespace` tracks upstream main HEAD in PR-ready form.
- **Proposal issue**: earendil-works/pi#8834 — closed NOT_PLANNED; the
  notification target for tracked releases (step 6). One comment per tracked
  release, informational tone, never a relitigation.

## Automation status (P1/P2 live; P3 manual)

The tracker workflow on fork `main` now runs the full pipeline:
**detect** (release compare + tracking issue) → **L1** mechanical re-base
(`patch/ci/mechanical-rebase.sh` + `patch/ci/verify.sh`; clean cherry-pick →
auto-PR `namespace-patch-next` → `namespace-patch`) → **L2** agentic repair
on L1 failure (headless `pi` pinned to the **currently released patched pi**
— self-hosting: patch N repairs toward patch N+1; deepseek-routed, 90-min
wall-clock breaker; pipeline re-verifies gates post-agent; green → PR, red →
escalation comment on the tracking issue). Agent pin source:
`origin/namespace-patch:patch/MANIFEST.json` (forkReleaseTag/tarballAsset),
fallback = stock npm package at the same base version, never `latest`.

Prerequisite secrets (repo settings): `DEEPSEEK_API_KEY` (the L2 agent's
provider). Merge of the pipeline PR remains the human/agent gate; release
cut + upstream comment are manual step 4/6 below (P3 automation deferred).

The manual procedure below is the fallback when Actions are disabled and
remains the contract the automation implements.

## The loop

1. **[automatic] Release monitor** — `.github/workflows/namespace-patch-tracker.yml`
   on fork `main` runs daily (cron) and on `workflow_dispatch`. It compares
   upstream's latest release tag with `patch/MANIFEST.json → baseTag` on
   `namespace-patch`. On a mismatch it opens (or refreshes the body of) a
   tracking issue titled `patch-tracking: pi.namespace -> <new tag>`, labeled
   `patch-tracking`, linking the release notes, this file, and the stale
   manifest. Dedup: one open issue per target tag.
2. **[harness] Re-base in a dedicated worktree** — never in the shared main
   checkout (its `node_modules` tracks upstream main; the release base needs
   its own, and a branch cannot be checked out in two worktrees):
   ```bash
   git -C <main-checkout> checkout main            # free the branch first
   git -C <main-checkout> worktree add ../pi-ns-<XY.Z> namespace-patch
   git -C <main-checkout> fetch upstream --tags
   git -C ../pi-ns-<XY.Z> checkout -B namespace-patch <new-tag>
   git cherry-pick <feature-commit> <version-stamp-commit>   # resolve if moved
   npm ci --no-audit --no-fund && npm run hydrate:model-data # gitignored data
   ```
   Version-stamp refresh: re-run the bump across every `packages/**/package.json`
   whose version equals the old stamp, then `npm install --package-lock-only`,
   `npm run shrinkwrap:coding-agent`, `npm run install-lock:coding-agent`
   (the pre-commit hook enforces all three).
3. **[harness] Verify on the new base**: `npm run check` (full chain) and the
   four touched suites (`skills` / `prompt-templates` / `resource-loader` /
   `package-manager`) — record the actual counts in MANIFEST
   `verification.tests`. Never silence a failing suite to make the artifact
   green; if upstream moved those tests, record the new numbers.
4. **[harness] Rebuild artifacts + fork release**:
   ```bash
   npm run build
   ( cd packages/coding-agent && npm pack --pack-destination /tmp )
   git format-patch -1 <feature-commit> --stdout  > patch/pi-namespace.patch
   git format-patch -1 <stamp-commit>   --stdout  > patch/version-stamp.patch
   # update MANIFEST.json (baseTag/baseSha/commits/patchVersion "<X.Y.Z>-namespace.<n>"/
   #   forkReleaseTag/tarballAsset) and this file's History table
   git add patch && git commit -m "patch: track <new-tag> (<X.Y.Z>-namespace.<n>)"
   git push origin namespace-patch
   gh release create "v<X.Y.Z>-namespace.<n>" --target <stamp-commit> \
     /tmp/earendil-works-pi-coding-agent-<X.Y.Z>-namespace.<n>.tgz \
     patch/pi-namespace.patch patch/version-stamp.patch \
     --title "pi.namespace <X.Y.Z>-namespace.<n>" --notes "<upstream release link; verification summary>"
   ```
5. **[harness] Close the fork tracking issue** with the new `patchVersion`,
   verification summary, and release link. Remove the worktree
   (`git worktree remove`).
6. **[harness] Notify the proposal issue** (earendil-works/pi#8834) — exactly
   one comment per tracked release, template:
   > Patch tracking note: upstream `<new-tag>` released; the maintained
   > `pi.namespace` patch now tracks it (`<X.Y.Z>-namespace.<n>`; full check
   > chain + touched suites green on the release tree; prebuilt tarball
   > attached to [v<X.Y.Z>-namespace.<n>](<release-url>)). No action
   > requested — posted for anyone following the feature.
   Rules of engagement: informational only; no maintainer @mentions; if a
   maintainer asks to stop, freeze this step and record the request here.
7. **[harness] Mirror to `package-namespace`** (main-HEAD form) when
   convenient: rebase onto upstream main, same verification, push. Keeps the
   PR-ready branch current in case upstream reconsiders.

## Distribution tiers

- **A (default)**: prebuilt tarball on the fork GitHub Release — one-line
  `npm install -g <asset-url>`; the only tier most users need.
- **B/C (source)**: the two `.patch` files / `apply.sh`, for people who build
  or want to read the diff.
- **Deferred**: a resident scoped npm package (`@maskshell/pi-coding-agent`)
  and a Homebrew tap — only if stable demand appears; both add long-term
  registry/tap maintenance and an exit cost if upstream reopens.

## Cadence and decay

- The monitor runs daily; the harness re-base should land before the next
  upstream release where possible.
- GitHub disables scheduled workflows after 60 days of repo inactivity — the
  tracking loop itself generates activity; if it lapses, re-enable via
  `gh workflow enable namespace-patch-tracker`.
- If the patch fails to apply cleanly for two consecutive releases, or the
  feature intersects an upstream refactor, open a fork issue labeled
  `patch-tracking` with `status: at-risk` and decide: rework, or retire the
  artifact (one final informational comment upstream, then archive).

## History

| patchVersion | baseTag | release | note |
|---|---|---|---|
| 0.84.4-namespace.1 | v0.84.4 | v0.84.4-namespace.1 | first release-based artifact (cherry-pick of the #8834 implementation + version stamp) |
