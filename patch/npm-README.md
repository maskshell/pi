<div align="center">

# pi-namespace-patch

**[pi](https://github.com/earendil-works/pi) with first-class package namespaces for skills and prompt templates**

_Your package ships `review`; your users invoke `/acme:review` — no collisions, no renamed frontmatter, no silent shadowing._

[![npm](https://img.shields.io/npm/v/pi-namespace-patch.svg)](https://www.npmjs.com/package/pi-namespace-patch)
[![pi base](https://img.shields.io/badge/pi%20base-@BASE@-blueviolet)](https://github.com/earendil-works/pi/releases)
[![license](https://img.shields.io/badge/license-MIT-blue)](#license)

</div>

---

## What this is

The upstream pi coding agent as a drop-in npm alias, carrying exactly one maintained patch: **`pi.namespace`**. A package that declares a namespace exposes every skill and prompt template it ships under one prefix. Nothing else about pi changes.

This is not the official package — that is [`@earendil-works/pi-coding-agent`](https://www.npmjs.com/package/@earendil-works/pi-coding-agent). This alias tracks every upstream release through an automated re-base pipeline: same code, one feature ahead.

## The problem

pi loads skills and prompt templates from every installed package into one flat pool. On a name collision the first one found wins; there is no grouping and no provenance in the invocation surface:

```
/skill:review    ← the user's review? the project's? pkg-a's? pkg-b's?
/review          ← a prompt template or a skill? from where?
```

Authors cannot claim a prefix, users cannot tell where a resource came from, and same-named resources silently shadow each other.

## The fix

One field in the package manifest:

```json
{
  "name": "@acme/pi-toolkit",
  "pi": {
    "namespace": "acme",
    "skills": ["./skills"],
    "prompts": ["./prompts"]
  }
}
```

| | Before (flat pool) | With `"namespace": "acme"` |
|---|---|---|
| Skill invocation | `/skill:review` — collision risk | `/skill:acme:review` — canonical, unambiguous |
| Bare invocation | — | `/acme:review` — the package's unified surface |
| Prompt template | `/review` — may shadow a skill | `/acme:review` — prefixed, coexists |
| `SKILL.md` frontmatter | `name: review` | `name: review` — unchanged, spec-clean |
| User's own `/skill:review` | shadowed or shadowing | coexists — namespaces never occupy bare names |

## Quickstart

As a **user** there is nothing to learn — install, and packages that declare a namespace simply appear prefixed:

```bash
npm install -g pi-namespace-patch
pi --version    # @NPM_VERSION@
```

As a **package author**, add the `pi.namespace` field (two lines above), publish, and your resources are invocable in-session:

```
/acme:review          # unified surface: template first, then a skill of the same name
/skill:acme:review    # the unambiguous skill form
```

A real consumer: the [solidforge](https://github.com/maskshell/solidforge-pi) toolchain exposes its agent skills as `solidforge:*` through this mechanism.

## How it works

The mechanics, in order of depth:

- **Applied at load time.** The namespace never enters `SKILL.md` frontmatter or template filenames — the Agent Skills spec stays intact and resource content is untouched. pi composes `<ns>:<name>` when loading.
- **`/ns:name` is a unified surface.** Input resolves a prompt template owning that exact name first, then a skill whose exposed name matches. `/skill:<ns>:<name>` remains the explicit, unambiguous skill form.
- **Bare names keep working.** `/skill:review` still resolves when the namespaced resource is the unique owner of that base name and no bare skill shadows it; colon-bearing requests always resolve by exact match only.
- **Coexistence by construction.** User, project, and other-package resources with the same base name load beside namespaced ones — a namespaced skill no longer occupies its bare name.
- **Validated, not guessed.** The value must be lowercase `a-z`, `0-9`, hyphens; ≤64 chars; no leading/trailing or consecutive hyphens. An invalid string warns and the resources load un-namespaced; a non-string `pi.namespace` is dropped silently.
- **Package resolution only.** Namespaces come from pi's package resolution — a raw settings or CLI path pointing inside the package bypasses the prefix and loads bare.
- **Scoped to name-keyed resources.** Skills and prompt templates only. Themes and runtime-registered tools/commands are not renamed; packages shipping subagents through their own extension read `pi.namespace` and prefix agent names themselves.
- **Legacy colon-filenames** (`prompts/acme:cmd.md`) keep working via exact match; with a namespace declared they compose to `acme:acme:cmd` — migrate them to plain filenames.

## Versions and upstream tracking

- The version scheme `X.Y.Z-namespace.N` mirrors the upstream release it tracks (`X.Y.Z`) plus the fork patch revision (`N`). **Pin exact versions** — never ranges.
- Each upstream release flows through an automated pipeline: release detection, mechanical re-base, agent repair on conflict, full check chain plus touched suites, then OIDC trusted publishing with signed provenance.
- `pi --version` on this alias reports `@NPM_VERSION@` (registry-stamped); the [GitHub tarball](@TARBALL_URL@) reports the workspace form `@PLUS_VERSION@` — same build, never rebuilt.

## Provenance and trust

- Every registry version is derived from the verified GitHub release asset of [maskshell/pi](https://github.com/maskshell/pi).
- Published via npm trusted publishing (OIDC); each version carries a signed provenance statement.
- The patch is a maintained proposal ([earendil-works/pi#8834](https://github.com/earendil-works/pi/issues/8834)); the full patch chain, gates, and tracking records are public on the [`namespace-patch` branch](https://github.com/maskshell/pi/tree/namespace-patch/patch).

## FAQ

**Is this the official pi?**
No. Install `@earendil-works/pi-coding-agent` for that. This alias is upstream pi plus the namespace patch; everything else is identical.

**Does it change my existing skills and templates?**
No. Namespacing is opt-in per package. User and project resources load exactly as before, and packages without `pi.namespace` behave identically to upstream.

**What happens when upstream releases?**
The pipeline re-bases and publishes a tracking version, typically within a day of the upstream tag.

**Can I mix this with the official package?**
Pick one per environment — both provide the `pi` binary.

## License

MIT, as upstream.
