# Plan Tasks Contract Reference

Use this reference to keep generated task and DAG artifacts compatible with repository validators.

## Path And Naming

- Path pattern: `tasks/tasks-<4digit>-<slug>.md`
- Path pattern: `tasks/trd-<4digit>-<slug>.md`
- Path pattern: `tasks/dag-<4digit>-<slug>.md`
- Path pattern: `tasks/dag-<4digit>-<slug>.json`
- Paired PRD pattern: `tasks/prd-<4digit>-<slug>.md`
- Planning artifact path: `.blackboard/artifacts/task-planning/<4digit>-<slug>.json`
- Valid examples:
  - `tasks/tasks-0001-auth-foundation.md`
  - `tasks/trd-0001-auth-foundation.md`
  - `tasks/dag-0001-auth-foundation.md`
  - `tasks/dag-0001-auth-foundation.json`
- Invalid examples:
  - `tasks/tasks-123-feature.md` (id is not 4 digits)
  - `tasks/trd-123-feature.md` (id is not 4 digits)
  - `tasks/dag_1234_feature.json` (wrong separators)
  - `tasks/tasks_1234_feature.md` (wrong separators)

## Required Task Block Signals

For every task heading that matches `### T-[0-9]+:`, include these lines:

1. `- Dependencies:`
2. `- Acceptance Criteria:`
3. `- Test Plan:`
4. `- Done Definition:`

Repository templates already include compliant structures:

- `tasks/templates/tasks.template.md`
- `tasks/templates/dag.template.md`
- `tasks/templates/dag.template.json`

## Validation Commands

Contract validation:

```bash
./scripts/validate-contracts.sh --project-dir .
```

Full gate validation (stack required):

```bash
./scripts/check.sh --stacks <csv|auto>
```

## Practical Authoring Notes

1. Use TRD as the primary decomposition input; do not drive task structure directly from PRD prose.
2. Use PRD as a constraints/goals guardrail only (goals, non-goals, constraints).
3. Maintain one-task-at-a-time execution semantics via explicit dependencies.
4. Ensure `tasks/tasks-*.md` `Dependencies` and DAG JSON `depends_on` are identical.
5. Use DAG JSON as machine source of truth; keep DAG markdown human-readable mirror.
6. Keep acceptance criteria measurable and implementation-agnostic.
7. Keep test plans command-oriented and reproducible.
8. Align Done Definition with gate requirement (`./scripts/check.sh` must pass).
9. Keep scope bounded to TRD architecture decisions and PRD goals/non-goals.
10. Populate task metadata fields `Task DAG`, `Task DAG Markdown`, and `Planning Artifact` with id/slug-consistent paths.
