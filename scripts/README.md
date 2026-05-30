# Scripts

These are the only executables in gauntlet. Each is ~50–100 lines of plain `bash` + inline `python3` — **read them before you trust them.** None reach the network, none use `eval`/`sudo`, none touch credentials.

| Script | Reads | Writes | Executes | Network |
|--------|-------|--------|----------|---------|
| `snapshot-diff.sh` | git history + working tree (`git diff`, merge-base) | a fresh `mktemp` temp dir only (`$AUDIT_TMP`) | `git`, `openssl` | none |
| `ledger-append.sh` | existing `.audit-flow/audit.log` (+ legacy `audit.log`) | appends **one line** to `.audit-flow/audit.log` in the audited repo | `python3` (SHA-256 hashing) | none |
| `ledger-verify.sh` | `.audit-flow/audit.log` | nothing (read-only) | `python3` | none |
| `ledger-query.sh` | `.audit-flow/audit.log` | nothing (read-only, prints to stdout) | `python3` | none |

## Guarantees

- **No network.** No `curl`, `wget`, downloads, or telemetry.
- **No `eval`, no `sudo`, no shell-out to fetched code.**
- **No secrets.** Nothing reads credentials, tokens, or env beyond `AUDIT_TMP` / `AUDIT_LOG` / `TRUNK`.
- **Write scope:** a temporary directory (`mktemp`) and `.audit-flow/audit.log` *inside the repo you're auditing*. Nothing else on disk is modified.

## Why these stay scripts

The ledger is tamper-evident because each entry's SHA-256 is computed over **byte-exact canonical JSON** (`sort_keys`, fixed separators) and chained to the previous entry's hash. That determinism must be identical on every append and every verify — fixed code guarantees it; ad-hoc inline code regenerated per run would drift and silently break the chain. A committed script is also auditable once and trusted thereafter.

## Running without scripts

gauntlet's adversarial debate (Challenger → Defender → Oracle) needs none of these. To run touching nothing: use plain `git diff` for the diff, and skip Phase 0 hashing and the Phase 4 ledger. You keep the PASS/VETO verdict; you lose diff-hash pinning and the tamper-evident record.
