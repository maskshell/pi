# FORK.md — what this fork carries

This is [maskshell/pi](https://github.com/maskshell/pi), a fork of
[earendil-works/pi](https://github.com/earendil-works/pi) maintained for one
purpose: carrying the **`pi.namespace`** feature (opt-in package namespace
for skills and prompt templates) as a **release-tracked patch**, after the
upstream proposal [#8834](https://github.com/earendil-works/pi/issues/8834)
was closed NOT_PLANNED. Everything else tracks upstream.

## Install the patched pi (one line)

```bash
npm install -g pi-namespace-patch
pi --version   # 0.85.1-namespace.3
```

`pi-namespace-patch` is the npm alias of the current release, published by
trusted publishing (OIDC, provenance attached) from the GitHub release
asset. Its version string is the release tag form (`X.Y.Z-namespace.N`);
the workspace-stamped artifact reports the semver build-metadata form
(`0.85.1+namespace.1`) — same build, two channel-specific version schemes
(npm collapses build metadata to one slot per `X.Y.Z`, so the alias cannot
reuse the `+` form). The registry suffix can also run ahead of the release
suffix: every publish occupies its version forever, so a registry-side fix
re-publishes at `N+1` (that is why the current alias is `-namespace.3`:
`.1` shipped a broken shrinkwrap, `.2` carried upstream's README on the
npm page — both superseded; the alias ships a dedicated fork README).

Pinned / registry-free install from the GitHub release:

```bash
npm install -g https://github.com/maskshell/pi/releases/download/v0.85.1-namespace.1/earendil-works-pi-coding-agent-0.85.1-namespace.1.tgz
pi --version   # 0.85.1+namespace.1
```

What you get: a package declaring `"pi": { "namespace": "myorg" }` exposes
its skills and prompt templates under `<ns>:<name>` — `/skill:myorg:foo`,
the bare `/myorg:foo` (unified surface: template first, then exact skill
match), templates as `/myorg:foo`. Resource content stays untouched;
namespaced and same-named bare user/project resources coexist. Details and
the full changelog of the feature: the release notes linked above.

## Branch map

| Branch | Base | Purpose |
|---|---|---|
| `main` | upstream main | mirror; **sole fork-specific files are this FORK.md, the tracker workflow, and the npm publish workflow** (see below) |
| `namespace-patch` | upstream **release tag** | the artifact: feature commit + version-stamp commit + `patch/` directory (patches, MANIFEST, apply.sh, rules) |
| `package-namespace` | upstream main HEAD | PR-ready form, kept current in case upstream reopens the feature |

## Release tracking

`.github/workflows/namespace-patch-tracker.yml` watches upstream releases
daily and opens a `patch-tracking` issue here whenever the patch base falls
behind. The re-base, verification, rebuild, and upstream-notification
procedure is codified in
[patch/PATCH-TRACKING.md](https://github.com/maskshell/pi/blob/namespace-patch/patch/PATCH-TRACKING.md).
Each release is additionally published to npm as `pi-namespace-patch` by
`.github/workflows/publish-namespace-patch.yml` (trusted publishing, OIDC;
no local tokens or OTP).

## Mirror-clean policy

`main` intentionally stays a clean mirror of upstream main. The only
exceptions are `FORK.md`,
`.github/workflows/namespace-patch-tracker.yml`, and
`.github/workflows/publish-namespace-patch.yml`.
All feature content lives on `namespace-patch` / `package-namespace`.
