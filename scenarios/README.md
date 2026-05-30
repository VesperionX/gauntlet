# Gauntlet Pressure Scenarios

TDD-style scenarios per `writing-skills`. Run an agent **with** the skill loaded against each scenario; record pass/fail against the checklist.

## Baseline failures (pre-upgrade SKILL.md)

Observed when agents follow the legacy single-session skill:

| Failure mode | Scenario |
|--------------|----------|
| Speculation without Read | misleading-rebuttal |
| BLOCKING without concrete failure path | cosmetic-only |
| No context outside diff | security-sensitive, missing-tests |
| Skim not declared on large diffs | huge-diff |
| Uncited Defender rebuttals accepted | misleading-rebuttal |
| Prior VETO ignored on re-audit | re-audit |

## Pass criteria (post-upgrade)

- Phase 0 uses `scripts/snapshot-diff.sh` (merge-base hashes)
- Phase 0.25 triage lists deep/standard/skim/skip
- Phase 0.5 prime gathers conventions + static checks + impact analysis (graph MCP if available, else git/Read/Grep)
- Challenges include `evidence_type`, `confidence`, `reversibility`
- Defender REBUTTED includes `file:line` + quoted snippet
- Oracle downgrades speculative BLOCKING to WARNING when appropriate
- TL;DR block appears before transcript
- Ledger appended via `scripts/ledger-append.sh` to `.audit-flow/audit.log`

## Script smoke tests

[smoke-test.md](smoke-test.md) — repeatable shell checks for script behavior (Phase 0 loud-fail, ledger chain) that agent pressure scenarios don't cover.
