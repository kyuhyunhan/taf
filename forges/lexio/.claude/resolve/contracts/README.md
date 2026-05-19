# Feature contracts — schema & conventions

> Schema-only documentation (public, T1 methodology). The actual contract
> instances (`C-NNN-*.yaml`) are product-specific state and live in the
> private overlay at `$PRIVATE_ROOT/contracts/` — gitignored from this
> public methodology repo. Treat this directory analogously to how
> `holds.schema.yaml` (public) pairs with `$PRIVATE_ROOT/holds.yaml` (private).

## What a contract is

A behavioral spec for one shipped feature. Format:

| Field | Purpose |
|---|---|
| `id` | `C-NNN` (monotonic) |
| `title` | one-line summary |
| `source_commit` | commit where this invariant was first established |
| `layer` | which architectural layer the contract pins (e.g., client / server / cross-cutting) |
| `trigger` | the precondition (what causes this to run) |
| `effect` | the observable postcondition |
| `boundary` | what this contract does NOT cover; exceptions / non-goals |

Source of truth is the YAML, not commit messages. Commits drift; the
contract is the durable invariant. As long as `trigger → effect` still
holds (with `boundary` honored), the contract is green even if every
line of implementation has moved.

## File naming

`C-NNN-<short-kebab-slug>.yaml` — NNN is monotonic, slug is human grep.

## Lifecycle

| When | Action |
|---|---|
| Feature ships | maintain-loop `commit` phase writes the new `C-NNN.yaml` to the private overlay |
| Behavior change | trigger/effect/boundary updated, `source_commit` bumped |
| Feature removed | contract deleted (or kept in `_legacy/` with archive rationale) |
| Test authored | reference the contract ID in test code (e.g. `// contract: C-007`) |

## Where they live (path resolution)

Tools read contracts from `${PRIVATE_ROOT}/contracts/`. The default
convention is `$TAF_ROOT/../private/forges/<product>/contracts/`,
resolved via the env var set in `settings.local.json`.

## Cross-references

- Rubric: `.claude/resolve/audit.yaml#G3-C7`. Score levels:
  0 = directory absent / empty;
  1 = thin (< the feature-catalog threshold);
  2 = at threshold, partial test linkage;
  3 = every contract ID referenced in ≥1 test file.
- Score check: `.claude/scripts/audit-checks/g3-c7-contracts-coverage.sh`.
- Each contract's `id` is the canonical handle. Tests reference it by
  putting the ID (e.g. `C-001`) anywhere in the test file — freeform
  header comments (`* Contract: C-001`) work as well as inline
  `// contract: C-001`.

## Why this exists

Without contracts, the only durable description of a feature is the
commit message, which rots as the code changes. A contract survives
refactors: as long as `trigger → effect` still holds, the contract is
green even if every line of implementation moved.

## Why instances are private

The set of contract files for a forge is, by construction, the complete
feature catalog of that product — including future / unreleased
features. That makes the directory itself a high-value competitive
intelligence target. Per the public/private split methodology, schema
stays public; instances live in the private overlay.
