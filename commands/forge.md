---
description: Bind, sync, list, or unbind a forge (product-bound master + memory + workspace).
argument-hint: <subcommand> [args]
---

You are routing the `/forge` slash command. The user's argument is: $ARGUMENTS

## Forge root

The taf repo root is `$TAF_ROOT` (an environment variable set by `taf/setup`). Forges live at `$TAF_ROOT/forges/<product>/`. Scripts are on `PATH` via `$TAF_ROOT/scripts/`.

If `$TAF_ROOT` is not set in this session, fail with: "Run `taf/setup` and add the `export TAF_ROOT=...` line to your shell rc, then restart the session."

## Subcommand routing

Parse `$ARGUMENTS` into `<subcommand>` and remaining tokens.

If `$ARGUMENTS` is **a single token** (a product name like `lexio`), treat it as `bind <product>`.

Subcommands:

- `bind <product>` — bind the current session to that forge.
- `sync` — pull memory for the currently bound forge (or named one).
- `list` — list registered forges.
- `unbind` — drop the current forge binding.
- (no args) — print this help.

## Bind procedure

When binding to a forge named `<product>`:

1. Run via Bash: `forge-sync-memory <product>`.
   - With `sync_mode: git` (default) this is a no-op; with `pull-only` it pulls S3 → `$TAF_ROOT/forges/<product>/memory/`.
   - If the forge does not exist, abort and tell the user to run `forge-init <product>` first.
2. Read these files in order and incorporate them into the active context:
   - `$TAF_ROOT/forges/<product>/profile.yaml`
   - `$TAF_ROOT/forges/<product>/.claude/agents/<product>-master.md`
   - `$TAF_ROOT/forges/<product>/CLAUDE.md` (the workspace persona body — the master file may delegate the bulk of its persona content here)
3. From this point onward, **adopt the master persona** described in the master file plus the workspace `CLAUDE.md`. You are now `<product>-master` for the remainder of this session (or until `/forge unbind`).
4. Restrict sub-agent delegation to the `taa` journeymen named in `profile.yaml:allowed_subagents`. **Do not invent or define new sub-agent personas inline.** If a needed journeyman is missing, surface it to the user as a `taa`-level gap and continue without it.
5. When operating on the product, use the absolute path declared in `profile.yaml:workdir`. Read it freely. Edit it only after the user has explicitly approved a specific change (propose changes in patch form first).
6. Report to the user: bound product, workdir, last-sync timestamp, number of memory files loaded.

## Sync procedure

Run `forge-sync-memory <product>`. Report what changed (file count, last-sync timestamp).

## List procedure

Run `forge-list`. Show the user the names + workdirs.

## Unbind procedure

Drop the master persona for the rest of this session. Confirm: "Forge binding cleared. You are no longer `<product>-master`."

## Constraints

- Never modify the product's repo at `profile.yaml:workdir` without explicit user approval for that specific change. Read freely.
- Memory at `$TAF_ROOT/forges/<product>/memory/` is **append-only** atomic notes — invoke the `<product>-docs` skill (if present) to capture facts; never edit an existing note.
- Never define a new sub-agent persona inline. Sub-agents are `taa` journeymen, full stop.
- Never write any orchestrator metadata (forge files, `.claude/`, `memory/`, master files) into the product's workdir. The product must remain unaware that a forge exists for it.
