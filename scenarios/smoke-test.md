# Scenario: Script smoke tests

Repeatable shell checks for behavior that has no agent-facing pressure test. Run from the skill directory with `SKILL_DIR=.`.

## 1. Phase 0 fails loudly when SKILL_DIR is wrong

Guards the `SKILL.md` Phase 0 snippet — a bad `SKILL_DIR` must error, not silently print "Nothing to review."

```bash
SKILL_DIR=/nonexistent bash -c '
  [ -f "$SKILL_DIR/scripts/snapshot-diff.sh" ] || { echo "snapshot-diff.sh not found under $SKILL_DIR" >&2; exit 1; }
'; echo "exit=$?"
```

**Pass:** prints the not-found message and `exit=1`. **Fail:** `exit=0`.

## 2. Ledger chain verifies

```bash
bash scripts/ledger-verify.sh
```

**Pass:** `OK, N entries verified`. **Fail:** any `FAIL line …`.
