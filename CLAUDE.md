# TAF Development

> This file is auto-loaded into every Claude Code session — kept thin to
> conserve prompt tokens. Project setup, structure, and history live in
> `README.md` and `ETHOS.md`.

## Hard rules

1. **English only** — all files and documents.
2. **Forge layering** — sub-agent personas live in `taa`, skills live in `tas`. A forge **never defines** a new agent or skill. It names existing ones via `profile.yaml:allowed_subagents` + `skill_applicability`. If specificity can't be expressed generically, it goes in the forge's `memory/` corpus.
3. **Single source of truth per forge** — `forges/<product>/.claude/resolve/*.yaml` for workflows/agents/skills/gates. `forges/<product>/CLAUDE.md` is a thin pointer.
4. **Activation = in-session bind** — `claude` runs from any cwd; `/forge <product>` binds the session to `$TAF_ROOT/forges/<product>/`. No launcher.
5. **Telemetry and local state are gitignored** — `**/.entire/`, `**/settings.local.json`.

## Source-of-truth pointers

| Need | Path |
|---|---|
| What is a forge? | `ETHOS.md` |
| Setup on a new machine + 3-clone bootstrap order | `README.md` |
| Forge structure, runtime, memory sync modes | `README.md` + `profile.yaml.tmpl` |
| Add a new forge | `forge-init <product> --workdir <abs-path> [--s3 <uri>]` |
| Workflows / agents / skills / gates for forge X | `forges/<product>/.claude/resolve/` |
| Per-forge governance summary | `forges/<product>/CLAUDE.md` |

`taf` requires `tas` + `taa` installed on the same machine (`~/.claude/skills/`, `~/.claude/agents/`) — see `README.md` bootstrap section.
