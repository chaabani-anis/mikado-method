#!/usr/bin/env bash
# install.sh — Install the mikado-method skill into AI coding tools.
#
# Usage:
#   ./install.sh claude   [--global | --project <dir>] [--force] [--uninstall]
#   ./install.sh opencode [--global | --project <dir>] [--force] [--uninstall]
#   ./install.sh agents   [--project <dir>] [--force] [--uninstall]
#
# Targets:
#   claude    Claude Code    project: <dir>/.claude/skills/mikado-method
#                            global:  ~/.claude/skills/mikado-method
#   opencode  opencode       project: <dir>/.opencode/skills/mikado-method
#                            global:  ~/.config/opencode/skills/mikado-method
#   agents    AGENTS.md tools (Codex, Cursor, Copilot coding agent, Gemini CLI, ...)
#                            marked section in <dir>/AGENTS.md
#                            + full skill files in <dir>/docs/mikado/tools/
#
# Idempotent: same version installed = no-op. Upgrades replace files. Local
# modifications are detected via checksums and never overwritten without --force.
#
# Compatible with Bash 3.2+ (macOS default). No associative arrays used.

set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILES="SKILL.md EXAMPLE.md sample.mikado.md validate-mikado.sh"
MARKER_START="<!-- mikado-method:start -->"
MARKER_END="<!-- mikado-method:end -->"
CHECKSUM_FILE=".mikado-skill.sums"

err()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit 1
}

# -------------------------------------------------------
# Argument parsing
# -------------------------------------------------------
TOOL="${1:-}"
[[ -n "$TOOL" ]] || usage
shift

SCOPE="project"
PROJECT_DIR="$(pwd)"
FORCE=0
UNINSTALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global)    SCOPE="global" ;;
    --project)   shift; PROJECT_DIR="${1:?--project requires a directory}" ;;
    --force)     FORCE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help)   usage ;;
    *)           err "unknown option: $1 (use --help)" ;;
  esac
  shift
done

[[ -d "$PROJECT_DIR" ]] || err "project directory not found: $PROJECT_DIR"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

SRC_VERSION=$(sed -n 's/^  version: *//p' "$SRC_DIR/SKILL.md" | head -1)
[[ -n "$SRC_VERSION" ]] || err "cannot read metadata.version from $SRC_DIR/SKILL.md"

# -------------------------------------------------------
# Helpers
# -------------------------------------------------------
installed_version() {  # $1 = installed SKILL.md path
  [[ -f "$1" ]] && sed -n 's/^  version: *//p' "$1" | head -1 || true
}

write_checksums() {  # $1 = target dir, remaining = files
  local dir="$1"; shift
  command -v shasum >/dev/null 2>&1 || return 0
  (cd "$dir" && shasum "$@" > "$CHECKSUM_FILE")
}

verify_checksums() {  # $1 = target dir; returns 1 if local modifications
  local dir="$1"
  command -v shasum >/dev/null 2>&1 || return 0
  [[ -f "$dir/$CHECKSUM_FILE" ]] || return 0
  (cd "$dir" && shasum -c "$CHECKSUM_FILE" >/dev/null 2>&1)
}

copy_with_substitution() {  # $1 = src file, $2 = dest file, $3 = SKILL_DIR value
  sed "s|{{SKILL_DIR}}|$3|g" "$1" > "$2"
}

smoke_test() {  # $1 = installed validate-mikado.sh, $2 = installed sample
  local out
  out=$(bash "$1" "$2" 2>&1 || true)
  echo "$out" | grep -q "Root node found" || err "smoke test failed: validator did not parse the sample"
  info "smoke test OK (validator parses the bundled sample)"
}

# -------------------------------------------------------
# Skills family (claude, opencode)
# -------------------------------------------------------
install_skill_dir() {  # $1 = target dir, $2 = SKILL_DIR substitution value
  local target="$1" skill_dir_value="$2" f cur

  if [[ $UNINSTALL -eq 1 ]]; then
    case "$target" in
      */skills/mikado-method) ;;
      *) err "refusing to remove unexpected path: $target" ;;
    esac
    if [[ -d "$target" ]]; then
      rm -rf "$target"
      info "removed $target"
    else
      info "nothing to remove at $target"
    fi
    return 0
  fi

  cur=$(installed_version "$target/SKILL.md")
  if [[ -n "$cur" ]]; then
    if ! verify_checksums "$target"; then
      [[ $FORCE -eq 1 ]] || err "local modifications detected in $target — use --force to overwrite"
      info "overwriting locally modified installation (--force)"
    elif [[ "$cur" == "$SRC_VERSION" && $FORCE -eq 0 ]]; then
      info "already up to date (v$SRC_VERSION) at $target"
      return 0
    else
      info "upgrading v$cur -> v$SRC_VERSION"
    fi
  fi

  mkdir -p "$target"
  for f in $SKILL_FILES; do
    copy_with_substitution "$SRC_DIR/$f" "$target/$f" "$skill_dir_value"
  done
  chmod +x "$target/validate-mikado.sh"
  write_checksums "$target" $SKILL_FILES
  info "installed mikado-method v$SRC_VERSION to $target"
  smoke_test "$target/validate-mikado.sh" "$target/sample.mikado.md"
}

# -------------------------------------------------------
# AGENTS.md family
# -------------------------------------------------------
agents_section() {  # $1 = SKILL_DIR value (where full skill files live)
  cat <<EOF
$MARKER_START
## Mikado Method (refactoring workflow) — v$SRC_VERSION

When a refactoring spans multiple modules, causes cascading failures, or has unclear
dependencies, follow the Mikado Method as specified in \`$1/SKILL.md\`. Do not start
multi-module refactorings without it.

Key invariants (full rules in the spec):
- Confirm the goal (business-value framing) with the user before any file change.
- Exploration: naive attempt -> capture failures as graph nodes -> commit the tree file
  (prefix \`mikado-graph:\`) -> revert all code with \`git checkout -- .\` (never stash).
- Graphs live in \`docs/mikado/<goal>.mikado.md\` (rail notation: depth = leading \`│ \` rails).
- Execute true leaves first, one TDD cycle per leaf, one atomic commit per node
  (\`feat: ...\`), never a parent before all its children are \`[x]\`.
- Validate the graph with \`bash $1/validate-mikado.sh docs/mikado/<goal>.mikado.md\`
  after every tree commit, before execution, and before every leaf commit (must exit 0).

Worked example: \`$1/EXAMPLE.md\`.
$MARKER_END
EOF
}

install_agents() {
  local agents_file="$PROJECT_DIR/AGENTS.md"
  local tools_dir="$PROJECT_DIR/docs/mikado/tools"
  local skill_dir_value="docs/mikado/tools"
  local f tmp

  if [[ $UNINSTALL -eq 1 ]]; then
    if [[ -f "$agents_file" ]] && grep -qF "$MARKER_START" "$agents_file"; then
      tmp=$(mktemp)
      awk -v s="$MARKER_START" -v e="$MARKER_END" '
        $0 == s {skip=1; next}
        $0 == e {skip=0; next}
        !skip {print}
      ' "$agents_file" > "$tmp"
      mv "$tmp" "$agents_file"
      info "removed mikado-method section from $agents_file"
    else
      info "no mikado-method section in $agents_file"
    fi
    if [[ -d "$tools_dir" ]]; then
      for f in $SKILL_FILES; do rm -f "$tools_dir/$f"; done
      rm -f "$tools_dir/$CHECKSUM_FILE"
      rmdir "$tools_dir" 2>/dev/null || true
      info "removed skill files from $tools_dir"
    fi
    return 0
  fi

  if [[ -f "$agents_file" ]] && grep -qF "$MARKER_START" "$agents_file"; then
    if grep -qF "Mikado Method (refactoring workflow) — v$SRC_VERSION" "$agents_file" \
       && verify_checksums "$tools_dir" && [[ $FORCE -eq 0 ]]; then
      info "already up to date (v$SRC_VERSION) in $agents_file"
      return 0
    fi
    if ! verify_checksums "$tools_dir"; then
      [[ $FORCE -eq 1 ]] || err "local modifications detected in $tools_dir — use --force to overwrite"
      info "overwriting locally modified installation (--force)"
    fi
    tmp=$(mktemp)
    awk -v s="$MARKER_START" -v e="$MARKER_END" '
      $0 == s {skip=1; next}
      $0 == e {skip=0; next}
      !skip {print}
    ' "$agents_file" > "$tmp"
    mv "$tmp" "$agents_file"
  fi

  mkdir -p "$tools_dir"
  for f in $SKILL_FILES; do
    copy_with_substitution "$SRC_DIR/$f" "$tools_dir/$f" "$skill_dir_value"
  done
  chmod +x "$tools_dir/validate-mikado.sh"
  write_checksums "$tools_dir" $SKILL_FILES

  if [[ -f "$agents_file" && -s "$agents_file" ]]; then
    printf '\n' >> "$agents_file"
  fi
  agents_section "$skill_dir_value" >> "$agents_file"
  info "installed mikado-method v$SRC_VERSION section in $agents_file"
  info "full skill files in $tools_dir"
  smoke_test "$tools_dir/validate-mikado.sh" "$tools_dir/sample.mikado.md"
}

# -------------------------------------------------------
# Dispatch
# -------------------------------------------------------
case "$TOOL" in
  claude)
    if [[ "$SCOPE" == "global" ]]; then
      install_skill_dir "$HOME/.claude/skills/mikado-method" "$HOME/.claude/skills/mikado-method"
    else
      install_skill_dir "$PROJECT_DIR/.claude/skills/mikado-method" ".claude/skills/mikado-method"
    fi
    ;;
  opencode)
    if [[ "$SCOPE" == "global" ]]; then
      install_skill_dir "$HOME/.config/opencode/skills/mikado-method" "$HOME/.config/opencode/skills/mikado-method"
    else
      install_skill_dir "$PROJECT_DIR/.opencode/skills/mikado-method" ".opencode/skills/mikado-method"
    fi
    ;;
  agents)
    [[ "$SCOPE" == "project" ]] || err "the 'agents' target is project-only (no --global)"
    install_agents
    ;;
  *)
    err "unknown target: $TOOL (expected: claude, opencode, agents)"
    ;;
esac
