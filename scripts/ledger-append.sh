#!/usr/bin/env bash
# ledger-append.sh — append v2 NDJSON entry to .audit-flow/audit.log (hash-chained).
set -euo pipefail

AUDIT_LOG="${AUDIT_LOG:-.audit-flow/audit.log}"
ENTRY_JSON="${1:-}"

if [ -z "$ENTRY_JSON" ]; then
  echo "Usage: ledger-append.sh '<json-object>'" >&2
  echo "  Or pipe JSON via stdin" >&2
  exit 1
fi

if [ "$ENTRY_JSON" = "-" ]; then
  ENTRY_JSON=$(cat)
fi

mkdir -p "$(dirname "$AUDIT_LOG")"

# Resolve prev_hash: v2 chain or migrate from v1 audit.log
PREV_HASH=""
if [ -f "$AUDIT_LOG" ]; then
  PREV_HASH=$(tail -1 "$AUDIT_LOG" | python3 -c "
import sys, json
line = sys.stdin.read().strip()
if not line: sys.exit(0)
try:
    o = json.loads(line)
    print(o.get('entry_hash',''))
except json.JSONDecodeError:
    pass
" 2>/dev/null || true)
fi

# Legacy v1 audit.log at repo root
if [ -z "$PREV_HASH" ] && [ -f audit.log ]; then
  PREV_HASH=$(grep '^entry_hash:' audit.log 2>/dev/null | tail -1 | awk '{print $2}' || true)
fi

# Inject prev_hash if missing
ENTRY_JSON=$(printf '%s' "$ENTRY_JSON" | python3 -c "
import sys, json
o = json.load(sys.stdin)
if not o.get('prev_hash'):
    o['prev_hash'] = sys.argv[1] if len(sys.argv) > 1 else ''
if o.get('schema_version') is None:
    o['schema_version'] = 2
body = json.dumps(o, sort_keys=True, separators=(',', ':'))
# entry_hash over canonical body without entry_hash field
o_copy = dict(o)
o_copy.pop('entry_hash', None)
canonical = json.dumps(o_copy, sort_keys=True, separators=(',', ':'))
import hashlib
h = hashlib.sha256(canonical.encode()).hexdigest()
o['entry_hash'] = h
print(json.dumps(o, separators=(',', ':')))
" "$PREV_HASH")

echo "$ENTRY_JSON" >> "$AUDIT_LOG"
echo "$ENTRY_JSON" | python3 -c "import sys,json; o=json.load(sys.stdin); print('entry_hash='+o['entry_hash'])"
