# mikado-method

An agent skill that makes AI coding agents apply the **Mikado Method** on legacy code: large-scale
refactoring driven by a dependency graph, code-free exploration, leaf-first execution and
revert-on-failure, so the codebase stays shippable at every step.

Knowing the method isn't enough: under pressure, an agent keeps its patches instead of reverting,
skips exploration and forgets to record blockers. This skill turns the method into
non-negotiable rules checked at every step: three confirmation gates, a characterization-test
safety net (golden master) before any refactoring, one commit per leaf, and a graph validator
that stops the agent as soon as the graph is invalid.

**Read the article** explaining what the skill enforces and why:

- English: [Mikado Method: the Skill That Turns the Method into Non-Negotiable Rules](https://anischaabani.com/en/blog/mikado-method-skill)
- Français : [Mikado Method : le skill qui transforme la méthode en règles non négociables](https://anischaabani.com/blog/mikado-method-skill)

## Installation

```bash
git clone https://github.com/chaabani-anis/mikado-method
cd mikado-method

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

## Usage

Once installed, ask your agent for a cross-cutting refactoring. The skill drives it through:

1. **Gate 1** — the goal is restated in business-value terms and confirmed by you.
2. **Golden master gate** — coverage is measured on the modules to be touched; below 80% (or with
   no tests), characterization tests become the first prerequisite in the graph.
3. **Exploration** — naive attempts, failures captured as graph nodes, code reverted each cycle.
4. **Gate 3** — you choose the delegation level: you implement, the agent implements leaf by leaf,
   or the agent runs autonomously.
5. **Execution** — true leaves first, TDD per leaf, one atomic commit per node.

Graphs live in `docs/mikado/<goal>.mikado.md`. Validate one manually:

```bash
bash <skill-dir>/validate-mikado.sh docs/mikado/<goal>.mikado.md
```

A complete worked example is in [`EXAMPLE.md`](EXAMPLE.md); release history is in
[`CHANGELOG.md`](CHANGELOG.md).

## License

MIT
