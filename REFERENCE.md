# Gauntlet Reference

Full phase contracts, role prompts, schemas, and edge cases. The orchestrator is [SKILL.md](SKILL.md).

## Impact analysis (optional graph MCP)

**Default path (no MCP required):** `git log` on changed paths, Read surrounding files, Grep for callers/tests. Set `evidence_type: citation`.

**If `code-review-graph` MCP is available** and the repo is indexed, prefer: `detect_changes`, `get_impact_radius`, `get_affected_flows`, `query_graph pattern=tests_for`. Set `evidence_type: graph-query`. If these tools fail or the repo is not indexed, fall back to the default path above and note `graph_summary: unavailable` in the prime bundle.

## Phase 0 — Snapshot

Run from target repo root:

```bash
AUDIT_TMP=$(mktemp -d)
export AUDIT_TMP
bash "$SKILL_DIR/scripts/snapshot-diff.sh"
source "$AUDIT_TMP/meta.env" 2>/dev/null || true
```

Artifacts: `branch.diff`, `uncommitted.diff`, `combined.diff`, `files.txt`, `meta.env`.

## Phase 0.25 — Triage

For each path in `files.txt`, assign **deep | standard | skim | skip**:

| Tier | Examples |
|------|----------|
| deep | auth/, migrations/, security, payments, core domain logic |
| standard | app code, APIs, handlers |
| skim | config, generated code, lockfiles |
| skip | format-only, comments-only |

Show the user the tier list; they may override.

**Risk mode** — an explicit mode overrides auto-detection: `gauntlet fast` / `standard` / `deep` (dashes optional). Otherwise auto-detect:

- `deep` if any deep file OR static/graph high-risk flags
- `fast` if all skip/skim AND LOC &lt; 50
- else `standard`

## Phase 0.5 — Prime

Run in parallel:

### 1. Conventions

Read if present: `AGENTS.md`, `CLAUDE.md`, `CONTEXT.md`, `.audit-flow.yml`. Grep `docs/adr/` for paths overlapping changed files.

### 2. Static analysis

Detect the languages of the changed files, then run the project's own tools on those files **if installed** — no tool is required:

- `git diff --check` — whitespace/conflict-marker errors (always available)
- Python → `ruff check <files>`, `mypy <files>` (if a config exists)
- TS/JS → `eslint <files>`, `tsc --noEmit` (if `tsconfig.json`)
- Rust → `cargo clippy` (if `Cargo.toml`)

Tool-confirmed findings are **pre-sustained** (skip debate); still list in TL;DR. Pair with the per-language [Language micro-checklists](#language-micro-checklists) below for the manual pass.

### 3. Impact analysis

**Default:** `git log --oneline <path>` for changed files, Read surrounding files for callers/tests, Grep for import/call sites.

**If `code-review-graph` MCP available:** prefer `detect_changes`, `get_impact_radius` for top changed symbols, `get_affected_flows`, `query_graph` pattern `tests_for`.

### 4. Prior audit

```bash
bash "$SKILL_DIR/scripts/ledger-query.sh" --file <path> --verdict VETO
```

If prior VETO on overlapping files, set `prior_veto_requirements` for Oracle.

### 5. Absence checklist (seed Challenger)

- Missing error handling on new paths
- Missing tests for new behavior
- Missing validation at trust boundaries
- Missing logging/observability
- Missing docs for public API changes
- Missing migration for schema changes

Bundle as `prime.json` conceptually (diff + triage + conventions + static + graph + prior + absence).

## Phase 1 — Challenger (risk-adaptive)

Use **Task** subagents with **isolated context**. Each subagent receives ONLY: `combined.diff`, prime bundle, role prompt. Do NOT pass other subagents' output.

### Challenge schema

```
CHALLENGE-N: {title}
Severity: BLOCKING | WARNING | NIT
Location: {file}:{line}
Evidence: {concrete failure path or invariant violation}
Principle: {rule violated}
evidence_type: citation | static-analysis | graph-query | speculative
confidence: high | medium | speculative
reversibility: one-way-door | two-way-door
```

### Severity calibration

- **BLOCKING:** data loss, security breach, wrong business outcome, production crash
- **WARNING:** edge-case correctness, performance, compounding maintainability
- **NIT:** style, naming, minor readability

### Modes

| risk_mode | Task subagents |
|-----------|----------------|
| fast | 1× general Challenger |
| standard | 3× security, correctness, maintainability |
| deep | 6× security, correctness, performance, api-contract, test-coverage, convention |

### Specialist prompts (deep mode)

**security-challenger:** injection, authn/z, secrets, deserialization, SSRF, supply chain.

**correctness-challenger:** off-by-one, null deref, races, error paths, invariants.

**performance-challenger:** N+1, allocations, hot loops, query plans.

**api-contract-challenger:** backwards compat, semver, breaking changes (use callers_of if graph available).

**test-coverage-challenger:** untested branches (use tests_for).

**convention-challenger:** ADR/AGENTS violations, forbidden patterns from `.audit-flow.yml`.

### Aggregator

Dedupe challenges with same `file:line` + same principle. Renumber `CHALLENGE-1..N`.

## Phase 2 — Defender

**Isolated Task subagent.** Input: challenges only (not Challenger chain-of-thought).

```
CHALLENGE-N: {title}
Verdict: REBUTTED | CONCEDED
Argument: ...
Citation: {file}:{line}
Snippet:
```
{≤5 lines quoted from Read}
```

**Citation gate:** REBUTTED without Citation+Snippet → treat as CONCEDED.

Concessions require Fix + unified diff block.

## Phase 2.5 — Challenger rebuttal (optional)

Run only if Defender REBUTTED ≥1 with valid citations. One round; **new evidence only** (Read/graph). Max 3 counter-points.

## Phase 3 — Oracle

**Fresh Task subagent.** Input: Challenger transcript + Defender transcript only.

Per challenge: `SUSTAINED | OVERRULED` + one-sentence reasoning.

**Weighted veto:**

- Sustained `BLOCKING × high × one-way-door` → counts toward VETO
- Sustained `BLOCKING × speculative × two-way-door` → downgrade to strong WARNING unless concrete path added

Downgrade unsupported speculation.

**Cross-cutting themes:** systemic patterns across sustained issues.

**Prior VETO:** if `prior_veto_requirements` set, state each: ADDRESSED | NOT_ADDRESSED.

Overall: **PASS** (no sustained BLOCKING) | **VETO**.

## Phase 3.5 — Fix verification

Per sustained finding:

```
Finding: CHALLENGE-N
Fix: {smallest safe change}
Verify: {command}
Merge: blocking | follow-up | informational
```

## Phase 4 — Ledger

Build JSON per [schema/entry.v2.json](schema/entry.v2.json). Append:

```bash
AUDIT_LOG=.audit-flow/audit.log bash "$SKILL_DIR/scripts/ledger-append.sh" "$(cat entry.json)"
bash "$SKILL_DIR/scripts/ledger-verify.sh"
```

## Output format

Lead with the arena banner, then the TL;DR contract block, then the transcript:

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

```markdown
## TL;DR
Verdict: PASS | VETO
Action items:
1. [BLOCKING] ...
Review coverage:
- deep: ...
- standard: ...
- skim: ...
- skip: ...
Confidence & limitations: ...

--- full transcript ---

### Phase 0.25 Triage
...
```

### `--pr` flag

When user requests PR-format output, after TL;DR emit:

```
path/to/file.ts:42:BLOCKING — title. Evidence. Suggested fix.
```

Stdout only; never run `gh pr review` automatically.

## Skill handoffs (on VETO)

- Architectural / coupling issues → suggest `/improve-codebase-architecture`
- Test gaps → suggest `/tdd`

## Language micro-checklists

Activate by detected language (3–5 items each):

**Python:** bare `except:`, mutable default args, SQL string concat, missing `timeout=` on requests.

**TypeScript:** `any` on public API, missing `await`, `==` on ids, unhandled promise.

**Go:** ignored `err`, goroutine leak without cancel, race on shared map.

**Rust:** `unwrap()` on user input, `unsafe` without comment, blocking in async.

## Edge cases

- **Huge diff (&gt;500 LOC):** triage mandatory; declare skim/skip.
- **No git repo:** debate only; skip ledger.
- **Empty diff:** stop after Phase 0.
- **Re-audit:** new hash → new entry; never amend prior verdict.
- **Specific base:** user sets `TRUNK=develop` before snapshot script.

## Pressure scenarios

See [scenarios/](scenarios/) for TDD validation.
