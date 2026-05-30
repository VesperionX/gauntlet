# Scenario: Cosmetic-Only Change

## Setup

Diff is whitespace, import reorder, or comment-only (&lt;50 LOC, no logic).

## Agent prompt

> gauntlet fast

## Expected behavior

1. Explicit `gauntlet fast` forces risk mode `fast`.
2. Triage marks files **skip** or **skim**.
3. Verdict PASS with WARNING/NIT at most; no BLOCKING without concrete production failure.
4. Ledger still appended.

## Failure signals

- BLOCKING on style or formatting.
- Deep mode with six specialists invoked.
