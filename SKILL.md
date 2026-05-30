---
name: gauntlet
description: Use when reviewing a code change, diff, or PR. Triggers on "gauntlet", "run the gauntlet", "gauntlet fast/standard/deep" (or with --), "audit", "adversarial review", "audit my diff", or questions about past audit verdicts.
allowed-tools: Bash, Read, Task, Grep, Glob
---

# Gauntlet

Structured adversarial review: specialists challenge, Defender rebuts with citations, Oracle arbitrates. Outcome recorded to a tamper-evident ledger. Your code doesn't get rubber-stamped — it runs the Gauntlet and either survives or is cut down.

**Why this exists:** A single reviewer (human or AI) confirms its own assumptions — it argues one side and grades its own paper. Gauntlet splits review across **isolated subagents** that cannot see each other's reasoning: a Challenger attacks the diff, a Defender rebuts with mandatory citations, an Oracle arbitrates. You get a **PASS or VETO** verdict, a fix command per sustained finding, and a tamper-evident record of every past verdict.

**Philosophy:** Evidence before debate. Roles run in **isolated Task subagents** to avoid self-confirmation. Speed vs depth is explicit — say **`gauntlet fast` / `standard` / `deep`** (dashes optional) to force a mode.

**Details:** [REFERENCE.md](REFERENCE.md) · **Examples:** [EXAMPLES.md](EXAMPLES.md)

## Prerequisites

Git repository on a feature branch (or uncommitted changes on trunk). Run from repo root.

Skill scripts live beside this file: `scripts/`, `schema/`.

## Workflow overview

Whole numbers (0–4) are the core spine: snapshot → challenge → defend → arbitrate → record. Fractions are gates wedged between them — cheap filters before expensive debate (0.25, 0.5), fairness and actionability after (2.5, 3.5).

| Phase | Action | Why |
|-------|--------|-----|
| 0 | `scripts/snapshot-diff.sh` — merge-base diff, dual hashes | Pin exactly what's under review |
| 0.25 | Triage files → deep / standard / skim / skip; compute risk_mode | Don't pay deep-review cost on a lockfile bump |
| 0.5 | Prime: conventions, static checks, impact analysis, prior VETO | Evidence before debate — argue from facts, not vibes |
| 1 | Challenger subagent(s) by risk_mode: fast=1, standard=3, deep=6 | Attack the diff from independent angles |
| 2 | Defender subagent — citation gate on every REBUTTED | Force rebuttals to cite code, not hand-wave |
| 2.5 | Optional Challenger rebuttal (one round, if cited rebuttals exist) | Stop Defender getting the unchallenged last word |
| 3 | Oracle subagent — weighted verdict, cross-cutting themes | Neutral arbiter; downgrade speculation |
| 3.5 | Fix verification commands per sustained finding | Turn "broken" into "run X to confirm fixed" |
| 4 | `scripts/ledger-append.sh` → `.audit-flow/audit.log` | Tamper-evident memory; powers prior-VETO checks |

## Phase 0 — Snapshot

`SKILL_DIR` must point to the directory containing this SKILL.md — Claude Code provides it as the skill's base directory at load time. The default below covers the common install location; override it if the skill lives elsewhere.

```bash
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/gauntlet}"
[ -f "$SKILL_DIR/scripts/snapshot-diff.sh" ] || { echo "snapshot-diff.sh not found under $SKILL_DIR — set SKILL_DIR to the gauntlet skill directory." >&2; exit 1; }
AUDIT_TMP=$(mktemp -d)
export AUDIT_TMP
bash "$SKILL_DIR/scripts/snapshot-diff.sh" || { echo "Nothing to review."; exit 0; }
```

Report `diff_source`, `file_count`, `combined_hash` (first 12 chars). Stop if `EMPTY_DIFF`.

## Phase 0.25 — Triage

Classify each file in `$AUDIT_TMP/files.txt`. Show tiers to user (overridable).

**risk_mode:** explicit mode wins — `gauntlet fast` · `standard` · `deep` (dashes optional). Otherwise auto-detect: `fast` (all skip/skim & LOC&lt;50) · `deep` (any deep file or high-risk prime) · else `standard`.

## Phase 0.5 — Prime

1. Read `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `.audit-flow.yml`, relevant ADRs.
2. Static checks: run the project's own linters/typecheckers on changed files if available (`ruff`/`mypy`, `eslint`/`tsc`, `cargo clippy`, plus `git diff --check` for whitespace). Tool-confirmed findings are **pre-sustained** — skip debate, still list in TL;DR. See language micro-checklists in [REFERENCE.md](REFERENCE.md).
3. **Impact analysis** (default: `git log` on changed paths, Read surrounding files, Grep for callers/tests). If the `code-review-graph` MCP is available, prefer `detect_changes`, `get_impact_radius`, `get_affected_flows`, `tests_for` instead — see [REFERENCE.md](REFERENCE.md).
4. `ledger-query.sh` for prior VETO on overlapping files.
5. Apply absence checklist ([REFERENCE.md](REFERENCE.md)).

## Phase 1–3 — Debate (Task subagents)

**Do not** run Challenger, Defender, and Oracle in the same context.

Launch Task subagents per [REFERENCE.md](REFERENCE.md) prompts. Pass only diff + prime bundle (+ challenges to Defender; transcripts to Oracle).

Aggregate and dedupe challenges before Phase 2.

## Phase 4 — Ledger

Build v2 JSON entry (`schema/entry.v2.json`). Append:

```bash
AUDIT_LOG=.audit-flow/audit.log bash "$SKILL_DIR/scripts/ledger-append.sh" "$ENTRY_JSON"
bash "$SKILL_DIR/scripts/ledger-verify.sh"
```

## Output

Open with the **arena banner**, then the **TL;DR** machine block (verdict, action items, review coverage, limitations), then the full transcript. The TL;DR block is a fixed contract — keep its fields verbatim; the banner sits above it and never replaces it.

```
🔥 GAUNTLET // ENTER THE ARENA
----------------------------------------
[Phase 1] CHALLENGERS (<risk_mode>)
⚔️ <lens>        -> PASSED | FAILED
[Phase 2] 🛡️ DEFENDER — <n> rebutted / <n> conceded
[Phase 3] ⚖️ ORACLE — <one-line ruling>
----------------------------------------
✅ VERDICT: SURVIVED          (PASS)
🚫 VERDICT: VETOED — cut down in the Gauntlet   (VETO)
```

A challenger lens is `FAILED` when it raised a sustained finding, `PASSED` otherwise. Then the unchanged `## TL;DR` block and transcript.

**`--pr`:** also emit `path:line:body` lines for manual `gh pr review` — never auto-post.

## Edge cases

- No git → debate only, no ledger.
- Run without scripts (debate-only) → use plain `git diff` for the diff; skip Phase 0 hashing and Phase 4 ledger. Keeps the PASS/VETO verdict; loses diff-hash pinning and the tamper-evident ledger. ([scripts/README.md](scripts/README.md))
- Huge diff → triage mandatory ([scenarios/huge-diff.md](scenarios/huge-diff.md)).
- Re-audit after VETO → new hash, new entry; Oracle checks prior requirements.

## VETO handoffs

- Architecture → `/improve-codebase-architecture`
- Tests → `/tdd`
