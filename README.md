# mikado-method

An agent skill that makes AI coding agents apply the **Mikado Method** on legacy code: large-scale
refactoring driven by a dependency graph, code-free exploration, leaf-first execution and
revert-on-failure, so the codebase stays shippable at every step.

Knowing the method isn't enough: under pressure, an agent keeps its patches instead of reverting,
skips exploration and forgets to record blockers. This skill turns the method into
non-negotiable rules, enforced by confirmation gates and a graph validator.

## The article series

| | English | Français |
|---|---|---|
| 1. Why agents need the Mikado Method | [Taming Agentic Refactoring with the Mikado Method](https://anischaabani.com/en/blog/mikado-method-ai-agents) | [Domptez vos refactorings agentiques avec la Mikado Method](https://anischaabani.com/blog/mikado-method-ai-agents) |
| 2. What this skill enforces, and why | [Mikado Method: the Skill That Turns the Method into Non-Negotiable Rules](https://anischaabani.com/en/blog/mikado-method-skill) | [Mikado Method : le skill qui transforme la méthode en règles non négociables](https://anischaabani.com/blog/mikado-method-skill) |
| 3. A complete case study, replayable commit by commit | [Mikado Method in Action: an Agent Refactoring Replayable Commit by Commit](https://anischaabani.com/en/blog/mikado-method-example) | [Mikado Method en action : un refactoring d'agent rejouable commit par commit](https://anischaabani.com/blog/mikado-method-example) |

## Gates and rules at a glance

The full specification is in [`SKILL.md`](SKILL.md); the rationale is in article 2.

**Gates** — the agent stops and waits for you:

| Gate | When | What you decide |
|---|---|---|
| Gate 1 — Goal | Before any file change | Confirm or amend the goal, restated in business-value terms |
| Gate 2 — Pattern | Each exploration cycle that reveals a design need | Accept the proposed pattern (Ports & Adapters, Strategy…) or ask for another approach |
| Gate 3 — Delegation | Once the graph is stable and valid | Level 1: you implement · Level 2: the agent implements leaf by leaf, waiting for your "ok" · Level 3: autonomous |

**Golden master gate** — checked by the validator, not by you: before the first attempt, coverage
is measured on the modules to be touched. Below 80% (or with no tests), characterization tests
become a prerequisite node `{GM}`; otherwise the graph must declare
`[no-golden-master: coverage X% on <module>]`.

**Rules:**

1. **Confirmation gates** — Gates 1 to 3, in order, never skipped.
2. **Exploration writes no production code** — naive attempts are reverted with `git checkout -- .`;
   only the graph file survives, committed before each revert.
3. **Atomic leaf commit** — code, tests and the `[x]` mark in the graph land in the same commit.
4. **Children first** — a child is a prerequisite of its parent: the deepest nodes are implemented first.
5. **Mandatory validation** — `validate-mikado.sh` must exit 0 after every graph commit, before
   execution and before every leaf commit; otherwise the agent stops.

## What's in the repo

| File | Role | Installed |
|---|---|---|
| [`SKILL.md`](SKILL.md) | The skill itself: rules, gates, exploration and execution workflow, graph format, edge cases | Yes |
| [`EXAMPLE.md`](EXAMPLE.md) | Reference worked example (billing service / notification gateway): coverage check, graph evolution, TDD leaves in Java/TypeScript/Python, false-leaf anti-pattern, team workflow | Yes |
| [`validate-mikado.sh`](validate-mikado.sh) | Graph validator, 8 passes: parsing, traceability (`discovered-by`, `parent-error`), `requires:` references, cycles, tree direction via git history, orphans, golden master gate, true-leaf list for Gate 3. Bash 3.2+ | Yes |
| [`sample.mikado.md`](sample.mikado.md) | Minimal valid graph; used by the installer's smoke test | Yes |
| [`install.sh`](install.sh) | Multi-tool installer | No |
| [`CHANGELOG.md`](CHANGELOG.md) | Release history and versioning policy | No |

## Installation

Requirements: `bash` (3.2+, macOS default works) and `git`; the project you refactor must be a git
repository.

```bash
git clone https://github.com/chaabani-anis/mikado-method
cd mikado-method
```

Then pick your tool. Every target accepts `--project <dir>` (default: current directory),
`--force` and `--uninstall`.

### Claude Code

```bash
./install.sh claude --project /path/to/repo   # this repository only → .claude/skills/mikado-method/
./install.sh claude --global                  # all your projects     → ~/.claude/skills/mikado-method/
```

Claude Code discovers the skill on its next session. It loads it when your request matches the
skill's description (a multi-module refactoring), or explicitly with `/mikado-method`.
Commit `.claude/skills/` to share the project install with your team.

### opencode

```bash
./install.sh opencode --project /path/to/repo   # → .opencode/skills/mikado-method/
./install.sh opencode --global                  # → ~/.config/opencode/skills/mikado-method/
```

### Codex, Cursor, Copilot coding agent, Gemini CLI and other AGENTS.md tools

```bash
./install.sh agents --project /path/to/repo
```

Project scope only. The installer appends a marked section to the repo's `AGENTS.md` (created if
missing) with the key invariants and a pointer to the full skill, and copies the skill files to
`docs/mikado/tools/`. Commit both so every agent working on the repo follows the same rules.
If your tool does not read `AGENTS.md` by default, point its context-file setting at it (check
your tool's documentation).

### Any other harness

Copy `SKILL.md`, `EXAMPLE.md`, `validate-mikado.sh` and `sample.mikado.md` into the project, replace
`{{SKILL_DIR}}` in them with that folder's path, and reference `SKILL.md` from the tool's
instructions file.

### Updating and uninstalling

The installer is idempotent: re-running with the same version is a no-op and a newer version
replaces the files. Local modifications are detected by checksum and never overwritten without
`--force`. `--uninstall` removes the skill (and, for `agents`, only the marked section of
`AGENTS.md`). Each install ends with a smoke test: the validator must accept the bundled sample.

## Usage

Ask your agent for a cross-cutting refactoring, phrased as a goal, for example:

> Decouple `BillingService` from the SMTP client so invoices can be issued without sending email.

The agent then confirms the goal (Gate 1), checks coverage (golden master gate), explores and
builds the graph (Gate 2 at each pattern), asks for the delegation level (Gate 3) and implements
the leaves bottom-up, one commit each.

Graphs live in `docs/mikado/<goal>.mikado.md`. To validate one yourself:

```bash
bash <skill-dir>/validate-mikado.sh docs/mikado/<goal>.mikado.md
```

`<skill-dir>` is the install folder: `.claude/skills/mikado-method`,
`.opencode/skills/mikado-method`, `docs/mikado/tools`, or the global equivalent.
Exit code 0 means the graph is valid; anything else lists the defects to fix.

## License

MIT
