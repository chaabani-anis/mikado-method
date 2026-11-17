# mikado-method

An agent skill that makes AI coding agents apply the **Mikado Method** to large refactorings:
dependency graph, code-free exploration, leaf-first execution, revert on failure.

## Installation

Requires `bash` 3.2+ and `git`.

```bash
git clone https://github.com/chaabani-anis/mikado-method && cd mikado-method

./install.sh claude   --project <repo>   # Claude Code → <repo>/.claude/skills/mikado-method/
./install.sh claude   --global           #               ~/.claude/skills/mikado-method/
./install.sh opencode --project <repo>   # opencode    → <repo>/.opencode/skills/mikado-method/
./install.sh opencode --global           #               ~/.config/opencode/skills/mikado-method/
./install.sh agents   --project <repo>   # Codex, Cursor, Copilot, Gemini CLI… → section in AGENTS.md
                                         #   + skill files in <repo>/docs/mikado/tools/
```

`--project` defaults to the current directory. `--force` overwrites local changes, `--uninstall`
removes the skill. Re-running is safe; each install ends with a validator smoke test.

Other tools: copy `SKILL.md`, `EXAMPLE.md`, `validate-mikado.sh` and `sample.mikado.md` into the
project, replace `{{SKILL_DIR}}` with their folder, and reference `SKILL.md` in the tool's
instructions file.

## Usage

Ask your agent for a cross-cutting refactoring, phrased as a goal. The skill takes over. Graphs
are written to `docs/mikado/<goal>.mikado.md`; to check one yourself:

```bash
bash <install-dir>/validate-mikado.sh docs/mikado/<goal>.mikado.md
```

## How the skill works

**Gates:** the agent stops for your decision.
- **Gate 1:** confirm the goal, restated in business value, before any file change.
- **Gate 2:** accept or reject each refactoring pattern the exploration calls for.
- **Gate 3:** choose the delegation level: you implement, agent leaf by leaf, or autonomous.
- **Golden master** (checked by the validator): below 80% coverage, characterization tests
  come first.

**Rules:** exploration writes no production code (every attempt is reverted) · one atomic commit
per leaf · children before parents · `validate-mikado.sh` must pass after every graph change.

**Files:** `SKILL.md` (the skill) · `EXAMPLE.md` (worked example) · `validate-mikado.sh`
(8-pass graph validator) · `sample.mikado.md` (validator fixture) · `install.sh` ·
`CHANGELOG.md`.

## Articles

| | English | Français |
|---|---|---|
| Why | [Taming Agentic Refactoring with the Mikado Method](https://anischaabani.com/en/blog/mikado-method-ai-agents) | [Domptez vos refactorings agentiques avec la Mikado Method](https://anischaabani.com/blog/mikado-method-ai-agents) |
| The skill | [The Skill That Turns the Method into Non-Negotiable Rules](https://anischaabani.com/en/blog/mikado-method-skill) | [Le skill qui transforme la méthode en règles non négociables](https://anischaabani.com/blog/mikado-method-skill) |
| Case study | [An Agent Refactoring Replayable Commit by Commit](https://anischaabani.com/en/blog/mikado-method-example) | [Un refactoring d'agent rejouable commit par commit](https://anischaabani.com/blog/mikado-method-example) |

## License

MIT
