#!/usr/bin/env bash
# ledger-verify.sh — verify hash chain in .audit-flow/audit.log (v2 NDJSON + v1 yaml blocks).
set -euo pipefail

AUDIT_LOG="${AUDIT_LOG:-.audit-flow/audit.log}"
LEGACY_LOG="${LEGACY_LOG:-audit.log}"

python3 <<'PY'
import hashlib, json, re, sys, os

def verify_v2(path):
    prev = ""
    count = 0
    if not os.path.isfile(path):
        return 0, "no v2 log"
    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                o = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"FAIL line {i}: invalid JSON: {e}")
                sys.exit(1)
            eh = o.pop("entry_hash", "")
            ph = o.get("prev_hash", "")
            if ph != prev:
                print(f"FAIL line {i}: prev_hash mismatch (expected {prev[:16]}..., got {ph[:16]}...)")
                sys.exit(1)
            canonical = json.dumps(o, sort_keys=True, separators=(",", ":"))
            calc = hashlib.sha256(canonical.encode()).hexdigest()
            if calc != eh:
                print(f"FAIL line {i}: entry_hash mismatch")
                sys.exit(1)
            prev = eh
            count += 1
            o["entry_hash"] = eh
    return count, prev

def verify_v1(path):
    if not os.path.isfile(path):
        return 0, ""
    text = open(path).read()
    blocks = re.split(r"\n---\n", text)
    prev = ""
    count = 0
    for block in blocks:
        block = block.strip()
        if not block:
            continue
        lines = [l for l in block.splitlines() if not l.startswith("entry_hash:")]
        body = "\n".join(lines) + "\n"
        eh_line = [l for l in block.splitlines() if l.startswith("entry_hash:")]
        if not eh_line:
            continue
        eh = eh_line[0].split(":", 1)[1].strip()
        ph_line = [l for l in lines if l.startswith("prev_hash:")]
        ph = ph_line[0].split(":", 1)[1].strip() if ph_line else ""
        if ph != prev:
            print(f"FAIL v1 block {count+1}: prev_hash mismatch")
            sys.exit(1)
        calc = hashlib.sha256(body.encode()).hexdigest()
        if calc != eh:
            print(f"FAIL v1 block {count+1}: entry_hash mismatch")
            sys.exit(1)
        prev = eh
        count += 1
    return count, prev

v2_path = os.environ.get("AUDIT_LOG", ".audit-flow/audit.log")
legacy = os.environ.get("LEGACY_LOG", "audit.log")
n2, last2 = verify_v2(v2_path)
n1, last1 = verify_v1(legacy)
total = n2 + n1
if total == 0:
    print("OK, 0 entries (no log yet)")
else:
    print(f"OK, {total} entries verified (v2={n2}, v1={n1})")
PY
