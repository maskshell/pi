# FORK.md — what this fork carries

This is [maskshell/pi](https://github.com/maskshell/pi), a fork of
[earendil-works/pi](https://github.com/earendil-works/pi) maintained for one
purpose: carrying the **`pi.namespace`** feature (opt-in package namespace
for skills and prompt templates) as a **release-tracked patch**, after the
upstream proposal [#8834](https://github.com/earendil-works/pi/issues/8834)
was closed NOT_PLANNED. Everything else tracks upstream.

## Install the patched pi (one line)

```bash
npm install -g https://github.com/maskshell/pi/releases/download/v0.84.4-namespace.1/earendil-works-pi-coding-agent-0.84.4-namespace.1.tgz
pi --version   # 0.84.4-namespace.1
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
| `main` | upstream main | mirror; **sole fork-specific files are this FORK.md and the tracker workflow** (see below) |
| `namespace-patch` | upstream **release tag** | the artifact: feature commit + version-stamp commit + `patch/` directory (patches, MANIFEST, apply.sh, rules) |
| `package-namespace` | upstream main HEAD | PR-ready form, kept current in case upstream reopens the feature |

## Release tracking

`.github/workflows/namespace-patch-tracker.yml` watches upstream releases
daily and opens a `patch-tracking` issue here whenever the patch base falls
behind. The re-base, verification, rebuild, and upstream-notification
procedure is codified in
[patch/PATCH-TRACKING.md](https://github.com/maskshell/pi/blob/namespace-patch/patch/PATCH-TRACKING.md).

## Mirror-clean policy

`main` intentionally stays a clean mirror of upstream main. The only
exceptions are `FORK.md` and `.github/workflows/namespace-patch-tracker.yml`.
All feature content lives on `namespace-patch` / `package-namespace`.
