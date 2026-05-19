# Skill applicability — `tas` frontmatter convention

A forge's `profile.yaml:skill_applicability.include` filters `tas`
skills by tag. This document defines the tag convention.

## Frontmatter field

In any `tas/skills/<name>/SKILL.md`, you may add an `applicability` field:

```yaml
---
name: swift-patterns
description: Swift language patterns — async/await, optionals, ...
applicability: [apple, ios, macos, swift]
---
```

The field is **optional**. A skill without `applicability` is treated
as universal — visible to every forge.

## Standard tags

The following tags are reserved for cross-forge consistency. New tags
may be added as new forges arrive; keep them lowercase, hyphen-free,
single-word where possible.

| Tag           | Meaning                                            |
|---------------|----------------------------------------------------|
| `apple`       | Apple platform code (Swift/Obj-C, iOS/macOS/...)   |
| `ios`         | Specifically iOS                                   |
| `macos`       | Specifically macOS                                 |
| `swift`       | Swift language                                     |
| `web`         | Browser/server web stacks                          |
| `react`       | React ecosystem                                    |
| `next`        | Next.js                                            |
| `aws`         | AWS services                                       |
| `serverless`  | Serverless runtimes (Lambda, Workers, ...)         |
| `security`    | Security review and hardening                      |
| `docs`        | Documentation authorship                           |
| `process`     | Engineering process (review, standards)            |

## Matching rules

`profile.yaml:skill_applicability.include` accepts:

- exact tag (`apple`)
- glob over tag (`apple*`)
- exact skill name (`coding-standards`)
- glob over skill name (`swift-*`)

A skill is visible to the forge if any `include` rule matches AND no
`exclude` rule matches.

## Why this matters

As `tas` grows past a few dozen skills, every master agent's working
set should be filtered to what is actually applicable. A Swift forge
does not need Next.js skills clouding its system prompt; an AWS forge
does not need Apple platform skills. Applicability is how `tas` can
grow without overwhelming any one forge.

This is the load-bearing reason `tas` can grow indefinitely while
each forge stays focused.
