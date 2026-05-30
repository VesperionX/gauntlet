# Scenario: Re-audit After VETO

## Setup

1. Run audit on a branch with a known issue → VETO recorded in `.audit-flow/audit.log`.
2. Apply fixes; `combined_diff_hash` changes.
3. Run audit again.

## Agent prompt

> Re-audit my diff. Check prior VETO was addressed.

## Expected behavior

1. Prime loads `prior_veto_requirements` via `ledger-query.sh`.
2. Oracle section lists each prior requirement as ADDRESSED or NOT_ADDRESSED.
3. New ledger entry has new `audit_id`, new hashes, `prior_audit_id` set.
4. `ledger-verify.sh` reports OK for full chain.

## Failure signals

- Oracle ignores prior VETO.
- Same `entry_hash` or amended prior log line.
