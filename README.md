# gauntlet

Adversarial code review for AI agents. Your code doesn't get rubber-stamped — it runs the Gauntlet and either survives or is cut down. A single reviewer confirms its own assumptions — it argues one side and grades its own paper. Gauntlet splits review across **isolated subagents** that cannot see each other's reasoning: a Challenger attacks the diff, a Defender rebuts with mandatory citations, an Oracle arbitrates. You get a **PASS or VETO** verdict, a fix command per sustained finding, and a tamper-evident record of every past verdict.

Works in any git repo with no required setup beyond `git`, `bash`, and `python3`.

---

## Requirements

| Dependency | Required | Notes |
|------------|----------|-------|
| `git` | ✅ | Repository must exist |
| `bash` | ✅ | Scripts target bash 3.2+ |
| `python3` | ✅ | Ledger hashing + JSON parsing |
| `openssl` | ✅ | Diff hashing (`openssl dgst`) |
| [`code-review-graph` MCP](https://github.com/tirth8205/code-review-graph) | ⬜ optional | Adds structural impact analysis; the skill works without it |

Linters (`eslint`, `ruff`, `mypy`, `cargo clippy`) are used if present — none are required.

---

## Install

Place this skill's directory under your agent's skills path so it loads as `gauntlet`:

```bash
# Clone (replace <repo-url> with the repository you're installing from):
git clone <repo-url> ~/.claude/skills/gauntlet

# Or copy an existing local checkout:
cp -R gauntlet ~/.claude/skills/gauntlet
```

For other agents, use their skills directory instead (e.g. Codex `~/.agents/skills/`). No build step — the scripts run directly.

---

## Quickstart

In any git repo with uncommitted changes or a feature branch, tell your agent:

```
run the gauntlet
```

This picks the mode automatically — **standard** (3 challengers) for ordinary changes, **deep** (6) when the diff touches risky paths like `auth/` or migrations. To force a mode, name it (dashes optional):

```
gauntlet fast       # 1 challenger, quick pass
gauntlet standard   # 3 challengers
gauntlet deep       # 6 challengers
```

The skill also triggers on "audit", "adversarial review", "audit my diff", or questions about past verdicts. See [Modes](#modes) for what each tier runs.

---

## How it works

| Phase | What happens |
|-------|-------------|
| **0** | Snapshot diff (merge-base aware, dual hashes) |
| **0.25** | Triage files → deep / standard / skim / skip; set risk mode |
| **0.5** | Prime: conventions, static checks, impact analysis, prior VETOs |
| **1** | Challenger subagent(s) — attack from independent angles |
| **2** | Defender subagent — rebut with mandatory `file:line` citations |
| **2.5** | Optional Challenger rebuttal (new evidence only) |
| **3** | Oracle subagent — weighted verdict, downgrade speculation |
| **3.5** | Fix + verify command per sustained finding |
| **4** | Append hash-chained entry to `.audit-flow/audit.log` |

Phases 1–3 run in **isolated Task subagents** to prevent self-confirmation bias.

### Modes

Phase 0.25 picks a risk mode that scales challenger count to the diff:

| Mode | Challengers | When |
|------|-------------|------|
| **fast** | 1 general | You say `gauntlet fast`, or all files skip/skim and diff < 50 LOC |
| **standard** | 3 (security, correctness, maintainability) | Default for ordinary app-code changes |
| **deep** | 6 (security, correctness, performance, api-contract, test-coverage, convention) | Any deep-tier file (auth, migrations, payments, core logic) or a high-risk static/graph flag |

Triage tiers are shown before debate and you can override them.

Full phase contracts: [REFERENCE.md](REFERENCE.md) · Examples: [EXAMPLES.md](EXAMPLES.md)

---

## Output

```
## TL;DR
Verdict: PASS | VETO
Action items:
1. [BLOCKING] ...
Review coverage: deep: … standard: … skim: … skip: …
Confidence & limitations: …

--- full transcript ---
```

Add `--pr` to also emit `path:line:body` lines ready for `gh pr review` (never auto-posted).

---

## Ledger

Every audit appends a hash-chained NDJSON entry to `.audit-flow/audit.log` in the reviewed repo. Each entry's SHA-256 includes the previous entry's hash, so any edit to history is detectable. This powers:

- **Prior-VETO checks** — re-audits know which requirements were previously enforced.
- **Tamper detection** — `scripts/ledger-verify.sh` validates the hash chain.

Query past audits:

```bash
bash ~/.claude/skills/gauntlet/scripts/ledger-query.sh --verdict VETO --file src/auth.ts
```

---

## Scripts

gauntlet ships 4 small scripts (diff snapshot + ledger), each network-free and near-read-only. [`scripts/README.md`](scripts/README.md) documents exactly what each one reads, writes, and executes. The adversarial review itself needs none of them — you can run **debate-only**, touching nothing, and just forgo diff-hash pinning and the ledger.

---

## Configuration

Copy `.audit-flow.yml.example` to `.audit-flow.yml` in your repo root to customize priorities, mandatory paths, forbidden patterns, and Oracle weighting. All fields are optional.

---

## Optional: code-review-graph MCP

If you have the `code-review-graph` MCP server configured, gauntlet uses it for structural impact analysis (`detect_changes`, `get_impact_radius`, `get_affected_flows`, caller/test coverage). Without it, the skill falls back to `git log`, `Read`, and `Grep` — full functionality, slightly less structural context.

---

## Example run

`gauntlet deep` on a branch adding an unauthenticated export endpoint:

```
🔥 GAUNTLET // ENTER THE ARENA
----------------------------------------
[Phase 1] CHALLENGERS (deep)
⚔️ security      -> FAILED
⚔️ correctness   -> PASSED
[Phase 2] 🛡️ DEFENDER — 0 rebutted / 1 conceded
[Phase 3] ⚖️ ORACLE — sustained: unauthenticated data export
----------------------------------------
🚫 VERDICT: VETOED — cut down in the Gauntlet

## TL;DR
Verdict: VETO
Action items:
1. [BLOCKING] api/routes/user.ts:28 — add requireAuth to GET /users/export
Review coverage: deep: api/routes/user.ts
Confidence & limitations: static checks + manual read; no runtime tests run
```

A clean diff ends with `✅ VERDICT: SURVIVED`. Full worked examples: [EXAMPLES.md](EXAMPLES.md).

---

## License

MIT © 2026 VesperionX
