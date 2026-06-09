# mikado-method

An agent skill implementing the **Mikado Method**: systematic large-scale refactoring using a
dependency graph, leaf-first execution, and revert-on-failure — the codebase stays shippable
at every step.

## What's in the box

| File | Role |
|---|---|
| `SKILL.md` | The skill: prime rules, confirmation gates, exploration/execution workflow |
| `EXAMPLE.md` | Complete worked example (billing service / notification gateway) |
| `sample.mikado.md` | Minimal valid graph, used as validator fixture |
| `validate-mikado.sh` | 6-pass graph validator (mandatory gate in the workflow) |
| `install.sh` | Multi-tool installer |

## Installation

```bash
# Claude Code — current project          # Claude Code — all projects
./install.sh claude                      ./install.sh claude --global

# opencode — current project             # opencode — all projects
./install.sh opencode                    ./install.sh opencode --global

# AGENTS.md tools (Codex, Cursor, Copilot coding agent, Gemini CLI, ...)
./install.sh agents --project /path/to/repo
```

| Target | Installs to |
|---|---|
| `claude` (project) | `.claude/skills/mikado-method/` |
| `claude --global` | `~/.claude/skills/mikado-method/` |
| `opencode` (project) | `.opencode/skills/mikado-method/` |
| `opencode --global` | `~/.config/opencode/skills/mikado-method/` |
| `agents` | Marked section in `AGENTS.md` + full skill in `docs/mikado/tools/` |

Options: `--project <dir>` (default: current directory) · `--force` (overwrite local
modifications or reinstall same version) · `--uninstall`.

The installer is idempotent: re-running with the same version is a no-op, upgrades replace
files, and locally modified installations are never overwritten without `--force`.

## Quick start

Once installed, ask your agent to refactor something cross-cutting. The skill drives it through:
1. **Gate 1** — goal reformulated in business-value terms, confirmed by you
2. **Exploration** — naive attempts, failures captured as graph nodes, code reverted each cycle
3. **Gate 3** — delegation level (you implement / agent implements leaf-by-leaf / autonomous)
4. **Execution** — true leaves first, TDD per leaf, one atomic commit per node

Graphs live in `docs/mikado/<goal>.mikado.md`. Validate one manually:

```bash
bash <skill-dir>/validate-mikado.sh docs/mikado/<goal>.mikado.md
```

## Versioning

Single source of truth: `metadata.version` in the `SKILL.md` frontmatter, mirrored by git tags
(`v1.0.0`). See `CHANGELOG.md` for the policy and history.

## License

MIT
