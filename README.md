# taf — These Are Forges

The product-bound layer of the `ta-set` ecosystem.

`taf` sits above [`tas`](https://github.com/kyuhyunhan/tas) (skills) and [`taa`](https://github.com/kyuhyunhan/taa) (agents). Where `tas` provides pure-function tools and `taa` defines journeyman personas, `taf` binds a master smith, a smithy, and an anvil's stock of memory to a single product.

```
taf — forges  (this repo)
 ├── taa  — journeyman agents
 └── tas  — pure-function skills
```

## What lives here

This repo holds the forge **scaffolding** AND the **concrete forge instances**:

- `templates/`, `scripts/`, `commands/`, `policy/` — generic scaffolding (forge-init, `/forge` command, profile template, etc.).
- `forges/<product>/` — actual forge instances, tracked. Each carries its own `CLAUDE.md`, `profile.yaml`, `.claude/` (settings, agents, resolve YAML, hooks, skills), and `memory/`.

Everything resolves through `$TAF_ROOT` — an environment variable that points at this clone. There is no `~/.taf/` indirection.

## Quick start

### Fresh install

```bash
git clone https://github.com/kyuhyunhan/tas.git ~/workspaces/ta-set/tas && ~/workspaces/ta-set/tas/setup
git clone https://github.com/kyuhyunhan/taa.git ~/workspaces/ta-set/taa && ~/workspaces/ta-set/taa/setup
git clone https://github.com/kyuhyunhan/taf.git ~/workspaces/ta-set/taf && ~/workspaces/ta-set/taf/setup
```

`taf/setup` symlinks the `/forge` slash command into `~/.claude/commands/` and prints two `export` lines. Add them to your shell rc (`~/.zshrc` or `~/.bashrc`):

```bash
export TAF_ROOT="$HOME/workspaces/ta-set/taf"
export PATH="$TAF_ROOT/scripts:$PATH"
```

Reload (`source ~/.zshrc`) and confirm:

```bash
echo $TAF_ROOT
forge-list
```

### Use an existing forge from this repo on a new machine

After cloning taf and adding the exports above, every forge under `$TAF_ROOT/forges/` is immediately usable — no extra setup. The forge's settings, hooks, resolve system, skills, and memory are all already in place via git.

```bash
claude                    # any cwd
> /forge lexio            # bind session
```

### Bootstrap a new forge

```bash
forge-init <product> --workdir <abs-path>
# Optional: --s3 <uri> if you want S3-backed memory instead of the default git-tracked memory.
```

This creates `$TAF_ROOT/forges/<product>/` with the master persona, profile, settings, and an empty `memory/` tree. Then commit and push the new forge alongside taf.

## How a forge is structured

```
$TAF_ROOT/forges/<product>/
├── CLAUDE.md              # forge entry note (auto-loaded)
├── profile.yaml           # workdir, memory mode, skill applicability, allowed agents
├── memory/                # atomic notes (append-only) + overlays
└── .claude/
    ├── settings.json      # Claude Code workspace settings + hook matrix
    ├── agents/<p>-master.md
    ├── resolve/           # OPTIONAL: deterministic workflow YAML
    │   ├── manifest.yaml
    │   ├── workflows/*.yaml
    │   ├── agents.yaml
    │   ├── skills.yaml
    │   └── gates.yaml
    ├── scripts/           # OPTIONAL: resolve.sh + lint + gate scripts
    ├── skills/            # OPTIONAL: forge-local skills
    └── hooks/             # OPTIONAL: pre-task, pre-memory-write, etc.
```

The `resolve/`, `scripts/`, `skills/`, and `hooks/` blocks are optional and were pioneered by the lexio forge — see `forges/lexio/.claude/resolve/manifest.yaml` for a working example. Adopt them when a forge needs deterministic routing instead of prose CLAUDE.md guidance.

## What this repo does NOT contain

- Sub-agent definitions. Those live in `taa`.
- Product source code. A forge references its product via `profile.yaml: workdir`.
- Any LLM runtime, server, or daemon. The host is Claude Code.
- Secrets. Credentials, API keys, and bucket names with embedded auth do not belong here. (Bare bucket names are fine; AWS auth comes from the local credential chain.)

## Related

- [`tas`](https://github.com/kyuhyunhan/tas) — skills
- [`taa`](https://github.com/kyuhyunhan/taa) — agents
- See [`ETHOS.md`](ETHOS.md) for what a forge is and is not.
- See [`CLAUDE.md`](CLAUDE.md) for project structure and conventions.

This is not a framework. It is one developer's harness — built from actual workflow, shaped by real needs.
