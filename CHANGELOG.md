# Changelog

All notable changes to the mikado-method skill are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/). Versioning: [SemVer](https://semver.org/)
— MAJOR: breaks existing graphs or the validator contract · MINOR: new rules, sections, or checks
· PATCH: doc fixes and rewording.

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
