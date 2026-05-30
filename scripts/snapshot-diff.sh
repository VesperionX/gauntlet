#!/usr/bin/env bash
# snapshot-diff.sh — merge-base aware diff capture for gauntlet Phase 0.
# Outputs env-style metadata to stdout and writes artifacts under AUDIT_TMP.
set -euo pipefail

AUDIT_TMP="${AUDIT_TMP:-$(mktemp -d)}"
export AUDIT_TMP
mkdir -p "$AUDIT_TMP"

# Detect repo root
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  echo "ERROR: not a git repository" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel)
CWD=$(pwd)
if [ "$CWD" != "$REPO_ROOT" ]; then
  echo "WARN: cwd ($CWD) != repo root ($REPO_ROOT); diff may be incomplete" >&2
fi

# Detect trunk
TRUNK=""
if git rev-parse --verify main >/dev/null 2>&1; then
  TRUNK="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
  TRUNK="master"
elif git rev-parse --verify origin/main >/dev/null 2>&1; then
  TRUNK="origin/main"
elif git rev-parse --verify origin/master >/dev/null 2>&1; then
  TRUNK="origin/master"
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
DIFF_SOURCE=""
MERGE_BASE=""

if [ -n "$TRUNK" ] && [ "$CURRENT_BRANCH" != "$TRUNK" ] && [ "$CURRENT_BRANCH" != "$(basename "$TRUNK")" ]; then
  MERGE_BASE=$(git merge-base "$TRUNK" HEAD 2>/dev/null || echo "")
  if [ -n "$MERGE_BASE" ]; then
    git diff --find-renames "$MERGE_BASE"...HEAD > "$AUDIT_TMP/branch.diff" 2>/dev/null || true
    git diff --name-only --find-renames "$MERGE_BASE"...HEAD > "$AUDIT_TMP/branch-files.txt" 2>/dev/null || true
    DIFF_SOURCE="branch '$CURRENT_BRANCH' vs $TRUNK (merge-base ${MERGE_BASE:0:8})"
  else
    git diff --find-renames "$TRUNK" > "$AUDIT_TMP/branch.diff" 2>/dev/null || true
    git diff --name-only --find-renames "$TRUNK" > "$AUDIT_TMP/branch-files.txt" 2>/dev/null || true
    DIFF_SOURCE="branch '$CURRENT_BRANCH' vs $TRUNK"
  fi
else
  : > "$AUDIT_TMP/branch.diff"
  : > "$AUDIT_TMP/branch-files.txt"
  DIFF_SOURCE="uncommitted changes on '$CURRENT_BRANCH'"
fi

git diff --find-renames HEAD > "$AUDIT_TMP/uncommitted.diff" 2>/dev/null || true
git diff --name-only --find-renames HEAD > "$AUDIT_TMP/uncommitted-files.txt" 2>/dev/null || true

# Combined diff for review
cat "$AUDIT_TMP/branch.diff" "$AUDIT_TMP/uncommitted.diff" > "$AUDIT_TMP/combined.diff" 2>/dev/null || true

# Unified file list
{
  cat "$AUDIT_TMP/branch-files.txt" 2>/dev/null
  cat "$AUDIT_TMP/uncommitted-files.txt" 2>/dev/null
} | grep -v '^$' | sort -u > "$AUDIT_TMP/files.txt" || true

# Note binaries and submodules
if [ -s "$AUDIT_TMP/files.txt" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    if git check-attr diff -- "$f" 2>/dev/null | grep -q 'unsuitable'; then
      echo "BINARY: $f" >> "$AUDIT_TMP/notes.txt"
    fi
  done < "$AUDIT_TMP/files.txt"
fi
if [ -f .gitmodules ]; then
  echo "SUBMODULES: present" >> "$AUDIT_TMP/notes.txt"
fi

FILE_COUNT=$(grep -c . "$AUDIT_TMP/files.txt" 2>/dev/null || echo 0)
LOC=$(wc -l < "$AUDIT_TMP/combined.diff" | tr -d ' ')

BRANCH_HASH=$(openssl dgst -sha256 < "$AUDIT_TMP/branch.diff" | awk '{print $NF}')
UNCOMMITTED_HASH=$(openssl dgst -sha256 < "$AUDIT_TMP/uncommitted.diff" | awk '{print $NF}')
COMBINED_HASH=$(openssl dgst -sha256 < "$AUDIT_TMP/combined.diff" | awk '{print $NF}')

# Export metadata for caller
cat > "$AUDIT_TMP/meta.env" <<META
AUDIT_TMP=$AUDIT_TMP
DIFF_SOURCE=$DIFF_SOURCE
TRUNK=$TRUNK
MERGE_BASE=$MERGE_BASE
CURRENT_BRANCH=$CURRENT_BRANCH
FILE_COUNT=$FILE_COUNT
LOC=$LOC
BRANCH_HASH=$BRANCH_HASH
UNCOMMITTED_HASH=$UNCOMMITTED_HASH
COMBINED_HASH=$COMBINED_HASH
META

# Human-readable summary
echo "diff_source=$DIFF_SOURCE"
echo "file_count=$FILE_COUNT"
echo "loc=$LOC"
echo "combined_hash=${COMBINED_HASH:0:12}"
echo "audit_tmp=$AUDIT_TMP"

if [ ! -s "$AUDIT_TMP/combined.diff" ]; then
  echo "EMPTY_DIFF=1"
  exit 2
fi

exit 0
