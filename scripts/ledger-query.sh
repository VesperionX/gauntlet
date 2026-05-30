#!/usr/bin/env bash
# ledger-query.sh — query .audit-flow/audit.log
set -euo pipefail

AUDIT_LOG="${AUDIT_LOG:-.audit-flow/audit.log}"

FILE_FILTER=""
VERDICT_FILTER=""
SINCE=""
SUMMARY_ONLY=0

while [ $# -gt 0 ]; do
  case "$1" in
    --file) FILE_FILTER="$2"; shift 2 ;;
    --verdict) VERDICT_FILTER="$2"; shift 2 ;;
    --since) SINCE="$2"; shift 2 ;;
    --summary) SUMMARY_ONLY=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

python3 - "$AUDIT_LOG" "$FILE_FILTER" "$VERDICT_FILTER" "$SINCE" "$SUMMARY_ONLY" <<'PY'
import json, sys, os
from datetime import datetime

path, file_f, verdict_f, since, summary = sys.argv[1:6]
summary = summary == "1"
entries = []
if os.path.isfile(path):
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    entries.append(json.loads(line))
                except json.JSONDecodeError:
                    pass

if since:
    entries = [e for e in entries if e.get("timestamp", "") >= since]

if verdict_f:
    entries = [e for e in entries if e.get("verdict") == verdict_f]

if file_f:
    entries = [e for e in entries if file_f in e.get("files_reviewed", [])]

if summary:
    from collections import Counter
    c = Counter(e.get("verdict") for e in entries)
    for v, n in c.items():
        print(f"{v}: {n}")
    sys.exit(0)

for e in entries:
    print(json.dumps({
        "audit_id": e.get("audit_id"),
        "timestamp": e.get("timestamp"),
        "verdict": e.get("verdict"),
        "summary": e.get("summary"),
        "combined_diff_hash": (e.get("combined_diff_hash") or "")[:12],
        "files": len(e.get("files_reviewed", [])),
    }))
PY
