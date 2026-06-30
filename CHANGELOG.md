# Changelog

All notable changes to the mikado-method skill are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/)
— MAJOR: breaks existing graphs or the validator contract · MINOR: new rules, sections, or checks
· PATCH: doc fixes and rewording.

## [1.2.1] - 2026-06-30

### Fixed
- `validate-mikado.sh` no longer crashes under `set -euo pipefail` when all nodes are done:
  `grep "|pending$"` returning exit 1 on an empty match now correctly sets `PENDING_COUNT=0`
  instead of aborting the script.

## [1.2.0] - 2026-06-29

### Added
- **Golden master gate** — mandatory coverage checkpoint enforced before the first naive attempt.
  Before committing the initial graph, coverage on the modules to be touched must be declared:
  - Coverage < 80% or no test file → add `[ ] {GM} Golden master on <module>` to the tree.
    Leaf if a snapshot/approval lib already exists; intermediate if the lib or a seam must be
    created first (those become children of `{GM}`).
  - Coverage ≥ 80% and test file exists → add `[no-golden-master: coverage X% on <module>]`
    anywhere in the `.mikado.md` file.
  `validate-mikado.sh` now **errors** when neither declaration is present (Pass 7). Pass 8
  enumerates all true leaves and tags golden master leaves with `[GOLDEN MASTER GATE]` for the
  Gate 3 readout — no more manual leaf counting.

## [1.1.0] - 2026-06-10

### Added
- `validate-mikado.sh --no-git` — skips the git-history checks (discovered-by commit
  existence/message, parent-child ancestry) for fixtures and format examples with fictional
  SHAs. Structural passes (parsing, traceability annotations, requires resolution, cycle
  detection, orphans) still run. Never use it on a real graph.

### Changed
- Graphs inside `.mikado.md` files are now wrapped in a fenced ` ```text ` block so GitHub's
  Markdown preview renders the rails verbatim instead of collapsing the tree into one
  paragraph. The validator ignores fence and prose lines. (Shipped in commit `7bf0e87`.)
- `install.sh` smoke test now asserts the validator's real exit code on the bundled sample
  (via `--no-git`) instead of grepping for "Root node found".

## [1.0.0] - 2026-06-09

### Added
- `SKILL.md` — Mikado Method workflow with 5 Prime Rules, 3 user confirmation gates,
  delegation levels, pre-exploration audit, and edge-case table.
- Rail notation for dependency graphs: depth encoded by leading `│ ` rails, `{Nid}` node
  identifiers, `requires:` cross-references (DAG), `[discovered-by: <sha>]` and
  `[parent-error: ...]` traceability annotations.
- `validate-mikado.sh` — 6-pass graph validator (parsing, traceability, requires resolution,
  cycle detection, tree direction via git ancestry, orphan detection). Bash 3.2 compatible.
- `EXAMPLE.md` — complete worked example (extract notification sending from a billing service
  behind a `NotificationGateway` port), with per-cycle pattern proposals, TDD execution in
  Java/TypeScript/Python, false-leaf anti-pattern, and team workflow.
- `sample.mikado.md` — minimal valid graph used as validator fixture.
- `install.sh` — multi-tool installer: Claude Code and opencode (native skills, project or
  global scope) and AGENTS.md-compatible tools (Codex, Cursor, Copilot coding agent,
  Gemini CLI, ...). Idempotent, version-aware, detects local modifications, `--uninstall`.
- Tree-update commits use the `mikado-graph:` prefix, enforced by the validator.
