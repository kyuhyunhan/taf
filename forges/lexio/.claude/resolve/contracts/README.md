# Lexio feature contracts

> One YAML per shipped feature. Behavioral spec, not implementation.
> Format: `trigger` (what causes this to run) / `effect` (observable
> outcome) / `boundary` (where this contract stops applying).
>
> Source of truth = the YAML, not commit messages. Commits drift; the
> contract is the durable invariant.

## File naming

`C-NNN-<short-kebab-slug>.yaml` — NNN is monotonic, slug is human grep.

## Location

Contracts live under `.claude/resolve/contracts/` (relocated from the
forge root on 2026-05-16 — `git log --follow` traces history). The
contracts directory is treated as the feature catalog: lexio has no
separate feature registry, so every contract here represents one
shipped feature by construction.

## Cross-references

- Rubric: `.claude/resolve/audit.yaml#G3-C7` (≥90% of shipped features
  covered → score 2; +every contract ID appears in ≥1 test file → 3).
- Score check: `.claude/scripts/audit-checks/g3-c7-contracts-coverage.sh`.
- Each contract's `id` is the canonical handle. Tests reference it by
  putting the ID (e.g. `C-001`) anywhere in the test file —
  freeform header comments work (`* Contract: C-001`) as well as
  inline `// contract: C-001`.

## Why this exists

Without contracts, the only durable description of a feature is the
commit message, which rots as the code changes. A contract survives
refactors: as long as `trigger → effect` still holds, the contract is
green even if every line of implementation moved.
