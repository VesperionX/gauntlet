# Scenario: Missing Tests

## Setup

Diff adds new public function or API route with no test file changes. Graph or grep shows no `tests_for` coverage.

## Agent prompt

> Audit my diff.

## Expected behavior

1. Absence checklist triggers test-coverage challenge.
2. `evidence_type: graph-query` or citation from grep for missing tests.
3. Severity WARNING unless critical path (then BLOCKING with failure mode).
4. Fix verification suggests concrete test command.

## Failure signals

- No mention of missing tests.
- BLOCKING without explaining production impact.
