# Tasks Contract Reference

Use this reference to keep generated task files compatible with repository validators.

## Path And Naming

- Path pattern: `tasks/tasks-<4digit>-<slug>.md`
- Paired PRD pattern: `tasks/prd-<4digit>-<slug>.md`
- Valid examples:
  - `tasks/tasks-0001-auth-foundation.md`
  - `tasks/tasks-0123-checkout-rollback.md`
- Invalid examples:
  - `tasks/tasks-123-feature.md` (id is not 4 digits)
  - `tasks/tasks_1234_feature.md` (wrong separators)

## Required Task Block Signals

For every task heading that matches `### T-[0-9]+:`, include these lines:

1. `- Dependencies:`
2. `- Acceptance Criteria:`
3. `- Test Plan:`
4. `- Done Definition:`

Repository template already includes compliant structure:

- `tasks/templates/tasks.template.md`

## Validation Commands

Contract validation:

```bash
./scripts/validate-contracts.sh --project-dir .
```

Full gate validation (stack required):

```bash
./scripts/check.sh --stack <python|node|go>
```

## Practical Authoring Notes

1. Maintain one-task-at-a-time execution semantics via explicit dependencies.
2. Keep acceptance criteria measurable and implementation-agnostic.
3. Keep test plans command-oriented and reproducible.
4. Align Done Definition with gate requirement (`./scripts/check.sh` must pass).
5. Keep scope bounded to PRD goals and non-goals.
