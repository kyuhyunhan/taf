# Lexio Forge — Private Overlay

This forge's product-private artifacts (memory notes, holds entries,
local profile override) are **not stored in this public repository**.

Authoritative location on a developer machine:

```
~/workspaces/ta-set/private/forges/lexio/
├── memory/             (append-only atomic notes; see TAXONOMY.md inside)
├── holds.yaml          (active process holds; schema in .claude/holds.schema.yaml)
└── profile.local.yaml  (workdir abs path + machine-specific override)
```

The private overlay lives in a separate private git repository
(`kyuhyunhan/ta-set-private`, planned). Tool path resolution will be
wired in Phase 1B via `profile.yaml#private_root` with default convention
`$TAF_ROOT/../private/forges/<product>/`.

Forks of this public repo will not see any memory / holds / phase data.
That is by design — methodology is public, product state is not.
See migration history in commits tagged `phase-0-tourniquet` onward.
