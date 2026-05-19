# TAF — These Are Forges

## What a forge is

A `taf` is a forge bound to a single product.
Each forge is a self-contained system, holding three things:

- a **master smith**   — the product-bound manager persona
- a **smithy**         — the workspace: settings, hooks, profile,
                          skill applicability filter
- an **anvil's stock** — the memory corpus, the metal we have already
                          worked on this product, synced from S3

The forge is private to the product, not to the world. It lives
under `$TAF_ROOT/forges/<product>/` in the taf repo. It is never
committed to the *product's* repo — the product itself remains
unaware that a forge exists for it.

## What lives in a forge

A forge contains, and contains only:

- `master.md`        — the product-bound manager persona (one file)
- `profile.yaml`     — workdir, memory binding, applicability filter,
                        taa allowlist
- `memory/`          — S3-synced domain corpus
- `settings.json`    — workspace permissions and hooks
- `CLAUDE.md`        — entry note for anyone (or anything) reading
                        the forge directly

It does **not** contain sub-agent definitions. Sub-agents are
journeymen hired from `taa`. The master may name which journeymen it
works with — `swift-developer`, `code-reviewer`, `swift-test-writer` —
but it never defines a new one. If a journeyman does not yet exist in
`taa`, that is a `taa` change, not a forge change. **Domain
specificity belongs in memory, not in new personas.**

## What a forge is not

A forge is not an orchestrator. We have no pipeline DSL, no plan
executor, no autonomous loop. The human runs the outer loop —
deciding when to step into the forge, what to forge next, and when
to ship. The smith works one strike at a time, between human turns.

If a future version grows autonomous execution, it will sit above the
forge as a separate concern, not inside it. The forge stays a place
where a human and a smith work together on one product.

## Why one forge per product

Domain knowledge does not generalize cleanly. The smith for a Swift
iOS app does not pick up the same hammers as the smith for a Next.js
service. `tas` (the universal toolset) and `taa` (journeyman agents)
are shared across forges; what is bound is the master, the smithy
layout, and the anvil's stock.

The lexio forge is not the X forge.

## Why memory grows but `taa` does not

Two things will grow over time as new products arrive:

- **`tas`** — new pure-function skills, scoped by `applicability` tag.
- **a forge's `memory/`** — new architecture notes, decisions, glossary
                              entries for that product.

One thing stays roughly fixed:

- **`taa`** — the journeyman roster. New personas are added only when
              the role itself is generic. A "Lexio data pipeline
              expert" is not a new persona; it is missing memory.

This is the rule that keeps `taa` reusable across forges.

## Relationship to `tas` and `taa`

```
taf — forges (this layer, private, product-bound instances)
 ├── taa — journeyman agents (public, generic personas)
 └── tas — tools (public, pure-function skills)
```

A forge declares which tools and which journeymen its master may
call. A forge never re-declares a tool or a journeyman that already
lives in `tas` or `taa`.

## Skill scope (per-forge convention)

When a forge carries optional automation under `.claude/skills/`, each skill is one of:

- `forge-*`     — operates on the forge itself (audit, harden, ...). Portable across
                  forges with zero domain edits.
- `<product>-*` — operates on the product the forge is bound to. Domain-bound by
                  definition; a parallel forge for product X would need its own
                  `X-tdd`, `X-review`, etc.

The convention exists so that, when a new forge is created, the `forge-*` set is
the *carriable* baseline and the `<product>-*` set is the work that's actually
new. Decide which namespace before authoring a new skill.

## Evolution — May 2026

Two parts of the original framing have softened since this ETHOS was
written, while the spirit is unchanged:

1. **"The forge is private. It lives under `~/.taf/forges/<product>/`."**
   Forges now live in the `taf` repo under `forges/<product>/` and are
   git-tracked. `$TAF_ROOT` (an env var pointing at the taf clone) is
   the only path you need; the `~/.taf/` runtime tree was retired in
   favour of a single canonical location. *Private* now means "secrets
   don't go in" (telemetry under `.entire/` is gitignored), not "the
   whole forge is unpublishable". The original *true* invariant
   — "never committed to the product's repo" — still holds.

2. **"A forge contains, and contains only: master.md, profile.yaml,
   memory/, settings.json, CLAUDE.md."** A forge MAY additionally
   carry forge-local automation under `.claude/`: a `resolve/` YAML
   set defining deterministic workflow routing, gate scripts,
   forge-local skills, and forge-local hooks. These are optional —
   small forges still consist of only the original five — but when
   present they replace prose CLAUDE.md guidance with executable
   data. See `taf/forges/lexio/.claude/resolve/` for a worked example.

3. **"memory/ — S3-synced domain corpus."** Memory may be either
   git-tracked (default; `sync_mode: git`) or S3-synced (opt-in;
   `sync_mode: pull-only`). Either way memory remains the anvil's
   stock — the rules for writing (atomic, append-only, layered) are
   unchanged.

The forge is still bound to one product, still not an orchestrator,
still a place where a human and a smith work together on one thing.
What changed is *where* the binding is stored, not *what* binding
means.
