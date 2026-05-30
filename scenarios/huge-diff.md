# Scenario: Huge Diff

## Setup

Mock or use a branch with 500+ changed lines across 20+ files (mix of app code, config, lockfile).

## Agent prompt

> Audit my diff. Run the gauntlet.

## Expected behavior

1. Run triage: classify files into deep / standard / skim / skip.
2. Tell user which files are deep-reviewed vs skimmed.
3. Risk mode should be `standard` or `deep`, not `fast`.
4. Challenges focus on security-sensitive and logic-heavy files, not lockfile noise.
5. TL;DR lists review coverage tiers.

## Failure signals

- Reviews every file at equal depth without declaring skim.
- BLOCKING on lockfile or formatting-only paths.
- No triage output.
