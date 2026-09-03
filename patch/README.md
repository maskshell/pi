# pi.namespace patch — maskshell fork artifact

An opt-in package namespace (`pi.namespace`) for skills and prompt templates,
maintained against upstream [earendil-works/pi](https://github.com/earendil-works/pi)
releases. Proposed upstream in [#8834](https://github.com/earendil-works/pi/issues/8834)
(closed NOT_PLANNED); this fork carries the feature as a release-tracked patch
for anyone who wants it, and as live field data should upstream reconsider.

- **What it does**: a package declaring `"pi": { "namespace": "myorg" }` exposes
  its skills and prompt templates under `<ns>:<name>` — `/skill:myorg:foo`, the
  bare `/myorg:foo` (unified surface: template first, then exact skill match),
  templates as `/myorg:foo`. Content untouched (SKILL.md frontmatter stays
  spec-compliant); namespaced and same-named bare user/project resources
  coexist; bare invocations keep resolving via a unique-base-name fallback.
- **Current base**: `MANIFEST.json → baseTag`. Two patches: the feature commit
  (`pi-namespace.patch`) and a fork version stamp (`version-stamp.patch`, makes
  `pi --version` self-identify).
- **Consumer**: [solidforge-pi](https://github.com/maskshell/solidforge-pi)
  ships `"namespace": "solidforge"` on this build.

## Install

**Tier A — prebuilt (default)**, one line, no clone/build (Node ≥ 22.19):

```bash
npm install -g https://github.com/maskshell/pi/releases/download/v0.84.4-namespace.1/earendil-works-pi-coding-agent-0.84.4-namespace.1.tgz
pi --version   # 0.84.4-namespace.1
```

**Tier B — from source**: clone upstream at `baseTag`, `git am` both patches,
`npm ci`, `npm run hydrate:model-data`, `npm run build` — see
`MANIFEST.json → install.tierB_source`.

**Tier C — script**: `bash apply.sh [target-dir]` (read it first; runs the
tier-B flow with verification gates).

## Branches in this fork

| Branch | Base | Purpose |
|---|---|---|
| `main` | upstream main | tracks upstream; sole fork-specific file is the release-monitor workflow |
| `namespace-patch` | upstream **release tag** | this artifact: feature + version-stamp commits + `patch/` directory |
| `package-namespace` | upstream main HEAD | PR-ready form kept current, if upstream ever reopens the feature |

## Update procedure

See [PATCH-TRACKING.md](PATCH-TRACKING.md) — the release monitor opens a
tracking issue in this fork whenever a new upstream release lands; the
procedure there re-bases the patch, rebuilds the tarball, cuts a fork release,
and (per policy) notifies the upstream proposal issue.
