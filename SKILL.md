---
name: mikado-method
description: Systematic approach for complex refactoring using dependency graphs, leaf-first execution, and revert-on-failure to keep the codebase always shippable
license: MIT
compatibility: claude-code, opencode, agents-md
metadata:
  version: 1.0.0
  audience: developer
  workflow: refactoring
---

## ⚠️ Prime Rules

### Rule 1 — Confirmation gates (in order, no skipping)

**Gate 1 — Goal.** Before any file change, present the Goal reformulated in business-value terms:
> "Proposed Goal: [goal]" — A) Confirm  B) Modify

Do not create `.mikado.md`, do not start naive attempts, until the user selects **A**.

**Gate 2 — Patterns (per exploration cycle).** After each naive attempt reveals new failures,
identify the refactoring pattern that the new nodes call for (e.g. Strategy, Repository, Registry)
and propose it before adding the node to the tree:
> "This failure suggests the [Pattern] pattern. A) Apply  B) Use a different approach"

Present one pattern per cycle, not all upfront. If the user selects **B**, adjust and re-ask before
updating the tree.

**Gate 3 — Delegation level.** After exploration is complete and the tree is stable, present the
full tree, list all true leaves, run `validate-mikado.sh` (must exit 0), then ask:
> "Exploration complete — N true leaves. Delegation level? (1 / 2 / 3)"

Do not write any production code until the user answers.

### Rule 2 — Exploration writes no production code

During exploration the **only allowed write** is the `.mikado.md` file.
Never create source files. Never modify production code.
Revert every naive attempt with `git checkout -- .` (not `git stash`, not `git clean -fd`).
The `.mikado.md` is committed immediately after creation so `git checkout -- .` cannot delete it.
Every later tree update must also be **committed before reverting** — once tracked, uncommitted
`.mikado.md` edits are discarded by `git checkout -- .` just like code.
After every revert: `git status` must show zero modified or untracked production files.

### Rule 3 — Atomic leaf commit

When a leaf is implemented and tests are green:
1. Mark `[x]` in `.mikado.md` **before** staging.
2. Run `validate-mikado.sh` — must exit 0.
3. `git add <implementation files> <test files> docs/mikado/<goal>.mikado.md`
4. `git commit -m "feat: [NodeDescription]"`

The `[x]` mark and the code are **always in the same commit**.

### Rule 4 — Tree direction invariant

Every child node is a **prerequisite** of its parent — it must be implemented **before** the parent.
Read: "To complete [Parent], [Child] must exist first."
The deeper the node, the earlier it is implemented. Leaves (deepest) always go first.

`discovered-by` invariant: the SHA of a child's discovery commit must be equal to or a descendant
of the SHA of the parent's discovery commit. A child discovered before its parent is a graph error.

> **Trap:** If you think "I need X before Y", then X is the **child** (deeper), Y is the **parent**.

### Rule 5 — Mandatory validation gate

Run `bash {{SKILL_DIR}}/validate-mikado.sh docs/mikado/<goal>.mikado.md`:
- After **every** tree update commit
- Before transitioning Exploration → Execution
- Before every leaf commit (Rule 3)

Exit ≠ 0 = **stop**. Fix the graph before continuing.

---

## When to Use Mikado

**Use Mikado when:** refactoring spans multiple modules, failures cascade, dependencies are unclear,
or you need to interrupt and resume safely.

**Use simple refactoring when:** the change fits in one file, dependencies are obvious, and one
commit suffices.

---

## Goal Definition

Frame goals in business value, not technical tasks.

| Avoid | Prefer |
|---|---|
| "Inject a notification gateway into BillingService" | "Invoices can be issued without the billing logic knowing how customers are notified, so billing tests run without an SMTP server" |
| "Replace the hardcoded SMTP client with an interface" | "A customer notification failure never blocks invoice issuance" |

---

## Delegation Levels

Ask once, after the stable tree and validation gate (Rule 1 Gate 3).

| Level | Who implements | Agent behaviour |
|---|---|---|
| **1** | Human | Agent lists true leaves + offers: A) human implements, agent reviews on return · B) agent writes a guide per leaf (no code). Stops here. |
| **2** | Agent, supervised | Leaf-by-leaf TDD. Pauses after each green commit: "Leaf done: [N]. Reply ok to continue." Never moves to next leaf without explicit approval. If the developer requests a change, update the tree, commit it, re-validate, then wait for "ok". |
| **3** | Agent, autonomous | Full graph without interruption. Single review request when root is `[x]`. |

---

## Core Cycle

```
Experiment in real files → failure → capture prereqs → update tree → commit tree → validate
        ↑                                                                              │
        └─────────────────── git checkout -- . ───────────────────────────────────────┘
```

---

## Exploration Mode

### Pre-exploration audit

Before any naive attempt, scan for references to concepts being introduced:
```bash
grep -r "<new_concept>" tests/ src/
```
Hidden fixtures that use the new concept as an "invalid" stand-in are **guaranteed regressions**.
Add them to the tree as nodes immediately.

### Naive attempt procedure

1. Create `docs/mikado/<goal>.mikado.md` with root only (graph wrapped in a ` ```text ` fence —
   see Dependency Tree Format).
2. `git add docs/mikado/<goal>.mikado.md && git commit -m "mikado-graph: initial graph for <goal> (root only)"`
   — commit immediately so `git checkout -- .` cannot delete the file.
3. Note current HEAD SHA: `git rev-parse HEAD` — this is `discovered-by` for all nodes this cycle.
4. Make the naive change **in the real source files** (never `/tmp`).
5. Run the full test suite. Capture all failures.
6. **Gate 2:** for each new node that implies a pattern, propose the pattern (A/B) before adding it.
7. Add child nodes with `[discovered-by: <sha>]` and `[parent-error: <file:line:msg>]`.
8. `git add docs/mikado/<goal>.mikado.md && git commit -m "mikado-graph: [target] requires [prereq] in file:line"`
   — commit the tree **before** reverting: `.mikado.md` is tracked, so `git checkout -- .` would
   discard uncommitted node additions along with the code.
9. `git checkout -- .` — revert all code. **Never `git stash`.**
10. `git status` — confirm zero modified production files.
11. `bash {{SKILL_DIR}}/validate-mikado.sh docs/mikado/<goal>.mikado.md` — must exit 0.
12. Repeat from step 3 on each newly discovered leaf until no new nodes emerge.

**Termination:** every apparent leaf attempted, no new nodes, tree stable, `git status` clean.

---

## Execution Mode

1. Identify deepest incomplete nodes (true leaves — zero incomplete children).
2. Select one leaf. Write a failing test (RED).
3. Implement the minimal change (GREEN). Refactor if needed.
4. Run the **full** test suite. If any previously-passing test fails → ⛔ STOP:
   - `git checkout -- .`, add the regression as a new child node, commit tree, validate, fix first.
5. Mark `[x]` in `.mikado.md` **before** staging (Rule 3).
6. Run `validate-mikado.sh` — must exit 0.
7. `git add <files> docs/mikado/<goal>.mikado.md && git commit -m "feat: [NodeDescription]"`
8. Never start a parent until all its children are `[x]`.

> **Late discovery:** if implementing a leaf reveals a new dependency, revert immediately,
> add the dependency as a child, commit the tree, validate, then implement the new node first.

---

## Dependency Tree Format

**Location:** `docs/mikado/<goal-name>.mikado.md`

Inside the `.mikado.md` file, wrap the graph in a ` ```text ` fenced block. Without the fence,
GitHub's Markdown preview merges consecutive lines into one paragraph and the `│ ` rails — the
tree structure — are lost. The validator parses line by line and ignores fence and prose lines.

```text
[ ] Goal: [business-value statement]            ← root: no rail, no {Nid}
│ [ ] {N1} [Change description] (file:line)     ← direct dependency of goal (depth 1)
│   [discovered-by: <sha>]
│   [parent-error: <file:line: error message>]
│ │ [ ] {N2} [Prerequisite] (file:line)         ← prerequisite of N1, implemented first (depth 2)
│ │   requires: {N3}, {N4}
│ │   [discovered-by: <sha>]
│ │   [parent-error: <file:line: error message>]
```

- Depth is encoded by leading `│ ` rails — one rail per nesting level, no list bullet.
  Annotation lines keep their node's rails. State markers: `[ ]` pending, `[x]` done.
- `{Nid}` — unique short identifier; used by `requires:` to express shared prerequisites (DAG).
- `[discovered-by: <sha>]` — HEAD SHA captured at the **start** of the cycle (step 3 above).
- `[parent-error: ...]` — exact compiler/test error that made this node necessary.
- `requires: {N3}, {N4}` — optional cross-references when two parents share a prerequisite.
- Child SHA ≥ parent SHA (Rule 4). Validate with `validate-mikado.sh`.

---

## Discovery Commit Formats

| Event | Format |
|---|---|
| Initial graph | `mikado-graph: initial graph for <goal> (root only)` |
| New dependency | `mikado-graph: [Node] requires [Prereq] in file:line` |
| False leaf | `mikado-graph: false leaf - [Node] blocked by [Dep]` |
| Leaf implemented | `feat: [NodeDescription]` |

*See `EXAMPLE.md` for complete worked example (fil rouge, Java/TS/Python TDD cycles, team workflow).*

---

## Edge Cases

| Situation | Action |
|---|---|
| `git stash` used for revert | Drop immediately (`git stash drop`). Use `git checkout -- .`. |
| New dependency during execution | Revert leaf. Add child node. Commit tree. Validate. Fix dependency first. |
| Test breaks in unrelated area | That failure is a new tree node. Revert. Do not continue the leaf. |
| Tree direction challenged | Re-read Rule 4. Child = prerequisite = deeper = implemented first. Verify before accepting. |
| Merge conflict between leaf branches | Add coordination node above both. Revert both. Implement coordination node first. |

---

## Quick Reference Checklist

1. ⚠️ **Gate 1 — Confirm Goal** (A/B). No file change until explicit A.
2. ⚠️ **Pre-exploration audit** — grep for new concepts in tests. Add hidden deps to tree.
3. Create `docs/mikado/<goal>.mikado.md` (root only) → **commit immediately**.
4. **Per exploration cycle:**
   - Note HEAD SHA (`git rev-parse HEAD`).
   - Naive attempt in real files. Run full test suite. Capture failures.
   - ⚠️ **Gate 2 — Propose pattern A/B** for each new failure that implies one.
   - Add nodes with `[discovered-by]` + `[parent-error]`.
   - Commit tree (**before** any revert — `git checkout -- .` would discard uncommitted tree edits).
   - `git checkout -- .` → `git status` (must be clean).
   - Run `validate-mikado.sh` — must exit 0.
5. Repeat cycles until tree is stable (no new nodes).
6. ⚠️ **Gate 3 — Ask delegation level (1/2/3)** after showing full tree + true leaves.
7. **Execute leaves bottom-up** (RED → GREEN → REFACTOR):
   - Full test suite after each change.
   - Mark `[x]` before staging.
   - Run `validate-mikado.sh`.
   - `git add <files + .mikado.md> && git commit -m "feat: [Node]"`.
   - ⛔ Regression → revert, add node, fix first.
8. Never start a parent before all children are `[x]`.
