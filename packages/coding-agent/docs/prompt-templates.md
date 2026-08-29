# Prompt Templates

Prompt templates turn Markdown files into reusable `/` commands. Use one when you want to reuse the same prompt without adding executable behavior or a larger set of supporting instructions.

A template can accept arguments and appear in command completion. Pi can load templates from personal configuration, project configuration, an explicit path, or a Pi package. Project configuration loads only after project trust is granted.

## Create a template

Create `~/.pi/agent/prompts/review.md`:

```markdown
---
description: Review staged git changes
argument-hint: "[focus]"
---
Review the staged changes. Focus on ${1:-correctness, security, and error handling}.
```

The filename becomes the command name, so this template is available as `/review`. The `description` appears in command completion. If it is omitted, Pi uses the first non-empty line.

`argument-hint` is optional. Use `<angle brackets>` for required arguments and `[square brackets]` for optional arguments.

Run `/reload` after adding or changing a template in an active session.

<a id="invoke-a-template"></a>

## Use a template

Type the template command in the editor:

```text
/review
/review concurrency
```

Pi expands the template before the resulting text enters the agent. Extensions receive the raw input first through the `input` event unless an extension command with the same name handles it.

Templates support these substitutions:

| Syntax | Result |
|---|---|
| `$1`, `$2`, … | One positional argument |
| `$@` or `$ARGUMENTS` | All arguments joined with spaces |
| `${1:-default}` | First argument, or a default value |
| `${@:-default}` | All arguments, or a default value |
| `${@:N}` | Arguments starting at position `N` |
| `${@:N:L}` | `L` arguments starting at position `N` |

Arguments follow shell-like quoting, so `/review "API compatibility"` supplies one argument containing a space.

## Package Namespaces

A package declaring `pi.namespace` exposes its templates under the composed
name `<namespace>:<name>`: `prompts/arm-tools.md` in a package with
`"namespace": "solidforge"` is invoked as `/solidforge:arm-tools`. When a
namespaced skill (not a template) owns that exact name, the bare form
resolves the template first — a same-named template always keeps precedence
over the skill fallback. The bare
invocation `/arm-tools` still resolves when that template is the unique
owner of the base name and no bare template shadows it; colon-bearing
requests always resolve by exact match only. Legacy colon-filenames
(`prompts/solidforge:arm-tools.md`) still work via exact match, but with a
namespace declared they compose to `<ns>:<ns>:<name>` — prefer plain
filenames. See
[packages.md](packages.md#namespace).

<a id="choose-where-it-loads"></a>

## Add it to Pi

Place the template in your user or project prompt directory. Conventional prompt directories load direct `.md` children only.

Settings and packages can select nested Markdown files; a package manifest can narrow discovery with explicit paths and globs. See [Settings](settings.md#resources) and [Pi Packages](packages.md) for these options.

Project templates become commands in the editor after trust is granted. Review their content before trusting an unfamiliar project. See [Security](security.md#understand-project-trust).
