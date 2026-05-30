# Scenario: Security-Sensitive Change

## Setup

Diff touches `auth/`, `api/login`, or adds raw SQL / `eval` / secret string.

## Agent prompt

> Audit my diff against main.

## Expected behavior

1. Triage marks auth paths as **deep**.
2. Risk mode `deep` or `standard` with security lens active.
3. Prime uses graph `detect_changes` / `get_impact_radius` if MCP available; else Read callers.
4. At least one security-flavored challenge with concrete exploit path or marked speculative.
5. BLOCKING only with data-loss / auth-bypass / injection failure mode.

## Failure signals

- No security challenges on auth changes.
- BLOCKING "might be insecure" without failure path.
