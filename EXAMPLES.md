# Gauntlet Examples

## PASS — cosmetic import reorder

**Triage:** all `skip`/`skim`, LOC 12 → `risk_mode: fast`

**Output:**
```
🔥 GAUNTLET // ENTER THE ARENA
----------------------------------------
[Phase 1] CHALLENGERS (fast)
⚔️ general       -> PASSED
----------------------------------------
✅ VERDICT: SURVIVED
```
```
Verdict: PASS
Action items: none
Review coverage: skip: src/foo.ts (import order only)
Confidence & limitations: static checks only; no runtime tests executed
```

Ledger entry: `verdict: PASS`, `blocking_issues: 0`

---

## VETO — missing auth check on new endpoint

**Triage:** `api/routes/user.ts` → deep → `risk_mode: deep`

**Output:**
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
```

**Challenger (security):**
```
CHALLENGE-1: Unauthenticated user data export
Severity: BLOCKING
Location: api/routes/user.ts:28
Evidence: GET /users/export reads DB with no session check; any caller gets all rows
Principle: Fail-closed auth on data endpoints
evidence_type: citation
confidence: high
reversibility: one-way-door
```

**Defender:** CONCEDED with fix diff adding `requireAuth` middleware.

**Oracle:** SUSTAINED → **VETO**

**Fix verification:**
```
Verify: npm test -- api/routes/user.test.ts
Merge: blocking
```

**Handoff:** suggest `/tdd` for coverage of auth edge cases.

---

## Re-audit after VETO

1. Prior entry in `.audit-flow/audit.log` has `verdict: VETO`, `audit_id: abc-123`.
2. User fixes and re-runs audit → new `combined_diff_hash`.
3. Prime loads `prior_veto_requirements` from ledger-query.
4. Oracle section:
   ```
   Prior VETO abc-123:
   - requireAuth on /users/export: ADDRESSED (middleware.ts:12)
   ```
5. New ledger entry links `prior_audit_id: abc-123`, fresh `entry_hash`.

Never edit the prior entry.
