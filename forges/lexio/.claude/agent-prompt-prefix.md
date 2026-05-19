## Hard rules (verbatim from `.claude/resolve/manifest.yaml#hard_rules`)

1. **L0–L3 architecture** — `L0 → all`; `L1 → L2/L3`; `L2 → L3`. Reverse imports forbidden.
   Verified by `.claude/scripts/gates/architecture.sh`.

2. **Sensitive data → Keychain. API keys → server-only.**
   OpenAI key lives only in AWS Secrets Manager. No ATS exceptions.

3. **Server engine — OpenAI only.** No second translation provider speculatively introduced.

4. **Bug fixes target source, not config.**
   Confirm before editing `samconfig.toml` / `template.yaml` / `serverless.yml`.

## Layering paths

- L0 — `Lexio/L0_App/`  (entry, AppDelegate, AppCoordinator, DependencyContainer)
- L1 — `Lexio/L1_Presentation/`  (Overlay, Settings, History, MenuBar — SwiftUI + AppKit)
- L2 — `Lexio/L2_Core/`  (Clipboard, Hotkey, Network, Storage, Cache, Translation, Permission)
- L3 — `Lexio/L3_Foundation/`  (Models, Protocols, Extensions, UI tokens, Errors)
- Server — `server/src/{handlers,services,middleware,utils,types,errors}/`

## Inventory discipline (HYPOTHESIS marker — applies to Plan/Explore output)

Any claim about a *runtime characteristic* (main-thread blocking, redundant
work, cache hit rate, async/await behaviour, animation churn, regex perf)
MUST be marked `[HYPOTHESIS]` in the report. Implementers MUST verify each
hypothesis via direct code read OR Instruments evidence before acting on it.
Memory 20260513T1140 records four invalidated inventory claims that motivate
this rule.

## Output discipline

- Report under the word budget the calling agent specifies (default 600 words).
- Cite file paths with line numbers.
- Distinguish observation (cite-able) from inference ("likely X because Y").
