#!/usr/bin/env bash
# validate-mikado.sh — Mandatory gate before Execution Mode and before every leaf commit
# Usage: bash validate-mikado.sh [--no-git] docs/mikado/<goal>.mikado.md
# Exit 0 = graph valid  |  Exit 1 = defects found, fix before continuing
#
# --no-git: skip checks that need the repo's git history (discovered-by commit
# existence/message, parent-child ancestry). For fixtures and format examples
# whose SHAs are fictional, e.g. the bundled sample.mikado.md. Never use it on
# a real graph: the git checks are the traceability guarantee.
#
# Run this script:
#   - after every tree-update commit
#   - before transitioning Exploration → Execution Mode
#   - before every leaf commit (Rule 3 of SKILL.md)
#
# Compatible with Bash 3.2+ (macOS default). No associative arrays used.

set -euo pipefail

NO_GIT=0
TREE_FILE=""
for arg in "$@"; do
  case "$arg" in
    --no-git) NO_GIT=1 ;;
    *) TREE_FILE="$arg" ;;
  esac
done

if [[ -z "$TREE_FILE" || ! -f "$TREE_FILE" ]]; then
  echo "ERROR: tree file not found: ${TREE_FILE}" >&2
  echo "Usage: bash validate-mikado.sh [--no-git] docs/mikado/<goal>.mikado.md" >&2
  exit 1
fi

ERRORS=0
WARNINGS=0

log_error()  { echo "  [ERROR]   $*" >&2; ERRORS=$(( ERRORS + 1 )); }
log_warn()   { echo "  [WARN]    $*"; WARNINGS=$(( WARNINGS + 1 )); }
log_ok()     { echo "  [OK]      $*"; }

# Graph syntax: depth is encoded by leading "│ " rails (one rail per level, no list bullet).
#   Root:  "[ ] Goal: ..."            (no rail, no {Nid})
#   Node:  "│ │ [ ] {Nid} description" (depth = number of rails)
ROOT_RE='^\[.?\][[:space:]]+(Goal:|Root:)'
NODE_RE='^((│ )+)\[.?\][[:space:]]+\{([A-Za-z0-9_-]+)\}[[:space:]]+(.*)'
NID_RE='^(│ )*\[.?\][[:space:]]+\{([A-Za-z0-9_-]+)\}'

# Temp files replace associative arrays (Bash 3.2 compat)
TMPDIR_LOCAL=$(mktemp -d)
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

NODES_FILE="$TMPDIR_LOCAL/nodes"           # lines: "nid|indent|description"
SHA_FILE="$TMPDIR_LOCAL/shas"             # lines: "nid|sha"
REQUIRES_FILE="$TMPDIR_LOCAL/requires"   # lines: "from_nid|to_nid"
PARENT_CHILD_FILE="$TMPDIR_LOCAL/pc"     # lines: "parent_nid|child_nid"

touch "$NODES_FILE" "$SHA_FILE" "$REQUIRES_FILE" "$PARENT_CHILD_FILE"

echo "=== Mikado Graph Validation: $TREE_FILE ==="
echo ""

# -------------------------------------------------------
# Pass 1 — Parse all nodes, collect IDs and indentation
# -------------------------------------------------------
echo "--- Pass 1: Parsing nodes ---"

ROOT_FOUND=0
LAST_NID=""
LAST_INDENT=-1

# indent_stack_file: lines "indent|nid" — we keep last seen nid at each indent
INDENT_STACK_FILE="$TMPDIR_LOCAL/indent_stack"
touch "$INDENT_STACK_FILE"

while IFS= read -r line; do
  # Root node (no rail, no {Nid}): "[ ] Goal: ..." or "[ ] Root: ..."
  if [[ "$line" =~ $ROOT_RE ]]; then
    ROOT_FOUND=1
    # Record root at indent 0
    grep -v "^0|" "$INDENT_STACK_FILE" > "$TMPDIR_LOCAL/is_tmp" 2>/dev/null || true
    echo "0|__ROOT__" >> "$TMPDIR_LOCAL/is_tmp"
    mv "$TMPDIR_LOCAL/is_tmp" "$INDENT_STACK_FILE"
    LAST_NID="__ROOT__"
    LAST_INDENT=0
    log_ok "Root node found"
    continue
  fi

  # Non-root node: "│ " rails + "[ ] {Nid} description"
  if [[ "$line" =~ $NODE_RE ]]; then
    rails="${BASH_REMATCH[1]}"
    nid="${BASH_REMATCH[3]}"
    desc="${BASH_REMATCH[4]}"
    # depth = number of leading "│ " rails
    indent=0
    r="$rails"
    while [[ "$r" == "│ "* ]]; do
      indent=$(( indent + 1 ))
      r="${r#│ }"
    done

    # Duplicate check
    if grep -q "^${nid}|" "$NODES_FILE" 2>/dev/null; then
      log_error "Duplicate node ID: {${nid}}"
    fi

    echo "${nid}|${indent}|${desc}" >> "$NODES_FILE"

    # Update indent stack: replace entry for this indent level
    grep -v "^${indent}|" "$INDENT_STACK_FILE" > "$TMPDIR_LOCAL/is_tmp" 2>/dev/null || true
    echo "${indent}|${nid}" >> "$TMPDIR_LOCAL/is_tmp"
    mv "$TMPDIR_LOCAL/is_tmp" "$INDENT_STACK_FILE"

    # Determine parent from indent stack (one rail less)
    parent_indent=$(( indent - 1 ))
    if [[ $parent_indent -ge 0 ]]; then
      parent_nid=$(grep "^${parent_indent}|" "$INDENT_STACK_FILE" | tail -1 | cut -d'|' -f2)
      if [[ -n "${parent_nid:-}" && "$parent_nid" != "__ROOT__" ]]; then
        echo "${parent_nid}|${nid}" >> "$PARENT_CHILD_FILE"
      fi
    fi

    LAST_NID="$nid"
    LAST_INDENT="$indent"
    log_ok "Node {${nid}} at depth ${indent}: ${desc:0:60}"
    continue
  fi

  # discovered-by annotation (belongs to LAST_NID)
  if [[ -n "$LAST_NID" && "$LAST_NID" != "__ROOT__" && "$line" =~ \[discovered-by:[[:space:]]*([a-f0-9]{6,40})\] ]]; then
    sha="${BASH_REMATCH[1]}"
    # Replace existing sha entry for this nid
    grep -v "^${LAST_NID}|" "$SHA_FILE" > "$TMPDIR_LOCAL/sha_tmp" 2>/dev/null || true
    echo "${LAST_NID}|${sha}" >> "$TMPDIR_LOCAL/sha_tmp"
    mv "$TMPDIR_LOCAL/sha_tmp" "$SHA_FILE"
  fi

  # requires: annotation (belongs to LAST_NID)
  if [[ -n "$LAST_NID" && "$LAST_NID" != "__ROOT__" && "$line" =~ requires:[[:space:]]*(.*) ]]; then
    raw="${BASH_REMATCH[1]}"
    # Extract all {Nid} references — strip braces, split on comma/space
    cleaned="${raw//\{/}"
    cleaned="${cleaned//\}/}"
    IFS=', ' read -ra refs <<< "$cleaned"
    for ref in "${refs[@]}"; do
      ref="${ref//[[:space:]]/}"
      [[ -z "$ref" ]] && continue
      echo "${LAST_NID}|${ref}" >> "$REQUIRES_FILE"
    done
  fi

done < "$TREE_FILE"

if [[ $ROOT_FOUND -eq 0 ]]; then
  log_error "No root node found. First node must be '[ ] Goal: ...' or '[ ] Root: ...' (no rail, no {Nid})."
fi

total_nodes=$(wc -l < "$NODES_FILE" | tr -d ' ')
echo ""

# -------------------------------------------------------
# Pass 2 — Traceability: every {Nid} needs
#          [discovered-by: <sha>] and [parent-error: ...]
# -------------------------------------------------------
echo "--- Pass 2: Traceability (discovered-by + parent-error) ---"

# Build sets of nids that have each annotation
DISC_FILE="$TMPDIR_LOCAL/has_discovered_by"     # nids with valid discovered-by
PERR_FILE="$TMPDIR_LOCAL/has_parent_error"      # nids with parent-error
touch "$DISC_FILE" "$PERR_FILE"

CURRENT_NID=""
while IFS= read -r line; do
  if [[ "$line" =~ $NID_RE ]]; then
    CURRENT_NID="${BASH_REMATCH[2]}"
  fi

  if [[ -n "$CURRENT_NID" ]]; then
    if [[ "$line" =~ \[discovered-by:[[:space:]]*([a-f0-9]{6,40})\] ]]; then
      sha="${BASH_REMATCH[1]}"
      if [[ $NO_GIT -eq 1 ]]; then
        echo "$CURRENT_NID" >> "$DISC_FILE"
        log_ok "{${CURRENT_NID}} discovered-by ${sha:0:7} (git checks skipped: --no-git)"
      elif git cat-file -e "${sha}" 2>/dev/null; then
        commit_msg=$(git log -1 --format="%s" "${sha}" 2>/dev/null || echo "")
        if [[ "$commit_msg" =~ ^mikado-graph: ]]; then
          echo "$CURRENT_NID" >> "$DISC_FILE"
          log_ok "{${CURRENT_NID}} discovered-by ${sha:0:7}: \"${commit_msg}\""
        else
          log_error "{${CURRENT_NID}} discovered-by ${sha:0:7} commit message must start with 'mikado-graph:' (got: \"${commit_msg}\")"
          echo "$CURRENT_NID" >> "$DISC_FILE"  # sha valid, message wrong — avoid double error
        fi
      else
        log_error "{${CURRENT_NID}} discovered-by ${sha:0:7}: commit not found in git history"
      fi
    fi

    if [[ "$line" =~ \[parent-error:[[:space:]]*.+\] ]]; then
      echo "$CURRENT_NID" >> "$PERR_FILE"
    fi
  fi
done < "$TREE_FILE"

while IFS='|' read -r nid indent desc; do
  if ! grep -q "^${nid}$" "$DISC_FILE" 2>/dev/null; then
    log_error "{${nid}} missing [discovered-by: <sha>]"
  fi
  if ! grep -q "^${nid}$" "$PERR_FILE" 2>/dev/null; then
    log_error "{${nid}} missing [parent-error: <file:line:msg>]"
  fi
done < "$NODES_FILE"

echo ""

# -------------------------------------------------------
# Pass 3 — Validate requires: references
# -------------------------------------------------------
echo "--- Pass 3: Requires references ---"

if [[ ! -s "$REQUIRES_FILE" ]]; then
  log_ok "No requires: references to validate"
else
  while IFS='|' read -r from_nid to_nid; do
    if grep -q "^${to_nid}|" "$NODES_FILE" 2>/dev/null; then
      log_ok "{${from_nid}} requires {${to_nid}} — valid"
    else
      log_error "{${from_nid}} requires {${to_nid}} — ID not found in tree"
    fi
  done < "$REQUIRES_FILE"
fi

echo ""

# -------------------------------------------------------
# Pass 4 — Cycle detection on requires graph (iterative Kahn)
# -------------------------------------------------------
echo "--- Pass 4: Cycle detection (requires graph) ---"

# Build in-degree and adjacency using temp files
INDEGREE_FILE="$TMPDIR_LOCAL/indegree"  # lines: "nid count"
touch "$INDEGREE_FILE"

# Initialize indegree to 0 for all nodes
while IFS='|' read -r nid indent desc; do
  echo "$nid 0" >> "$INDEGREE_FILE"
done < "$NODES_FILE"

# Count incoming edges from requires
while IFS='|' read -r from_nid to_nid; do
  # Increment to_nid's indegree
  count=$(grep "^${to_nid} " "$INDEGREE_FILE" | awk '{print $2}')
  count=$(( ${count:-0} + 1 ))
  grep -v "^${to_nid} " "$INDEGREE_FILE" > "$TMPDIR_LOCAL/id_tmp" 2>/dev/null || true
  echo "${to_nid} ${count}" >> "$TMPDIR_LOCAL/id_tmp"
  mv "$TMPDIR_LOCAL/id_tmp" "$INDEGREE_FILE"
done < "$REQUIRES_FILE"

QUEUE_FILE="$TMPDIR_LOCAL/queue"
PROCESSED_FILE="$TMPDIR_LOCAL/processed"
touch "$QUEUE_FILE" "$PROCESSED_FILE"

# Seed queue with zero-indegree nodes
grep " 0$" "$INDEGREE_FILE" | awk '{print $1}' > "$QUEUE_FILE" || true

PROCESSED_COUNT=0
TOTAL_NODES_WITH_REQUIRES=0
while IFS='|' read -r nid _; do
  if grep -q "^${nid}|" "$REQUIRES_FILE" 2>/dev/null || grep -q "|${nid}$" "$REQUIRES_FILE" 2>/dev/null; then
    TOTAL_NODES_WITH_REQUIRES=$(( TOTAL_NODES_WITH_REQUIRES + 1 ))
  fi
done < "$NODES_FILE"

while [[ -s "$QUEUE_FILE" ]]; do
  node=$(head -1 "$QUEUE_FILE")
  tail -n +2 "$QUEUE_FILE" > "$TMPDIR_LOCAL/q_tmp" && mv "$TMPDIR_LOCAL/q_tmp" "$QUEUE_FILE"
  echo "$node" >> "$PROCESSED_FILE"
  PROCESSED_COUNT=$(( PROCESSED_COUNT + 1 ))

  # Reduce indegree of neighbors
  while IFS='|' read -r from_nid to_nid; do
    if [[ "$from_nid" == "$node" ]]; then
      count=$(grep "^${to_nid} " "$INDEGREE_FILE" | awk '{print $2}')
      count=$(( ${count:-1} - 1 ))
      grep -v "^${to_nid} " "$INDEGREE_FILE" > "$TMPDIR_LOCAL/id_tmp" 2>/dev/null || true
      echo "${to_nid} ${count}" >> "$TMPDIR_LOCAL/id_tmp"
      mv "$TMPDIR_LOCAL/id_tmp" "$INDEGREE_FILE"
      if [[ $count -eq 0 ]]; then
        echo "$to_nid" >> "$QUEUE_FILE"
      fi
    fi
  done < "$REQUIRES_FILE"
done

# Any node still with indegree > 0 is part of a cycle
CYCLE_FOUND=0
while IFS=' ' read -r nid count; do
  if [[ "$count" -gt 0 ]]; then
    log_error "Cycle detected involving {${nid}}"
    CYCLE_FOUND=1
  fi
done < "$INDEGREE_FILE"

[[ $CYCLE_FOUND -eq 0 ]] && log_ok "No cycles detected in requires graph"

echo ""

# -------------------------------------------------------
# Pass 5 — Tree direction: child SHA >= parent SHA
# -------------------------------------------------------
echo "--- Pass 5: Tree direction (child discovered after parent) ---"

if [[ $NO_GIT -eq 1 ]]; then
  log_ok "Skipped (--no-git): ancestry checks require git history"
elif [[ ! -s "$PARENT_CHILD_FILE" ]]; then
  log_ok "No parent-child indentation relationships to check"
else
  while IFS='|' read -r parent_nid child_nid; do
    p_sha=$(grep "^${parent_nid}|" "$SHA_FILE" | cut -d'|' -f2)
    c_sha=$(grep "^${child_nid}|" "$SHA_FILE" | cut -d'|' -f2)

    if [[ -z "${p_sha:-}" || -z "${c_sha:-}" ]]; then
      # Cannot check — Pass 2 already reported missing SHAs
      continue
    fi

    if [[ "$p_sha" == "$c_sha" ]]; then
      log_ok "{${child_nid}} (${c_sha:0:7}) same cycle as {${parent_nid}} — direction OK"
    elif git merge-base --is-ancestor "$p_sha" "$c_sha" 2>/dev/null; then
      log_ok "{${child_nid}} (${c_sha:0:7}) discovered after {${parent_nid}} (${p_sha:0:7}) — direction OK"
    else
      log_error "{${child_nid}} (discovered-by: ${c_sha:0:7}) appears to have been discovered BEFORE its parent {${parent_nid}} (${p_sha:0:7}). Children are prerequisites: they must be discovered during or after the parent's naive attempt."
    fi
  done < "$PARENT_CHILD_FILE"
fi

echo ""

# -------------------------------------------------------
# Pass 6 — Orphan detection (warning only)
# -------------------------------------------------------
echo "--- Pass 6: Orphan detection ---"

REFERENCED_FILE="$TMPDIR_LOCAL/referenced"
touch "$REFERENCED_FILE"

# Mark nodes referenced via requires:
while IFS='|' read -r from_nid to_nid; do
  echo "$to_nid" >> "$REFERENCED_FILE"
done < "$REQUIRES_FILE"

# Mark nodes referenced as children in parent-child tree
while IFS='|' read -r parent_nid child_nid; do
  echo "$child_nid" >> "$REFERENCED_FILE"
done < "$PARENT_CHILD_FILE"

ROOT_CHILD_COUNT=0
while IFS='|' read -r nid indent desc; do
  if [[ "$indent" -eq 1 ]]; then
    ROOT_CHILD_COUNT=$(( ROOT_CHILD_COUNT + 1 ))
    echo "$nid" >> "$REFERENCED_FILE"
  fi
done < "$NODES_FILE"

while IFS='|' read -r nid indent desc; do
  if [[ "$indent" -gt 1 ]] && ! grep -q "^${nid}$" "$REFERENCED_FILE" 2>/dev/null; then
    log_warn "{${nid}} appears unreferenced (not a direct child of root, not in any requires:)"
  fi
done < "$NODES_FILE"

[[ $ROOT_CHILD_COUNT -gt 0 ]] && log_ok "${ROOT_CHILD_COUNT} direct child(ren) of root"

echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "=== Summary ==="
echo "  Nodes parsed  : ${total_nodes}"
echo "  Warnings      : $WARNINGS"

if [[ $ERRORS -eq 0 ]]; then
  echo "  Result        : VALID — graph is ready for next step"
  exit 0
else
  echo "  Result        : INVALID — $ERRORS error(s) found. Fix before continuing."
  exit 1
fi
