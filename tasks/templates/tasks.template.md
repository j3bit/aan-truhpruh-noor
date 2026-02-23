# TASKS-XXXX: <feature-name>

## Metadata
- File name: `tasks/tasks-<4digit>-<slug>.md`
- PRD: `tasks/prd-<4digit>-<slug>.md`
- Gate Stack: `<python|node|go>`
- Owner:
- Last Updated:

## Global Rules
- Execute one task at a time unless explicitly marked parallel-safe.
- Every task must include acceptance criteria and test plan.
- Do not close task before gate passes.

## Task List

### T-001: <task-title>
- Status: `todo`
- Dependencies: `none`
- Parallel-safe: `no`
- Description:
  - 
- Acceptance Criteria:
  1. 
  2. 
- Test Plan:
  1. 
  2. 
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stack <python|node|go>` exits with code `0`.
- Notes:
  - 

### T-002: <task-title>
- Status: `todo`
- Dependencies: `T-001`
- Parallel-safe: `no`
- Description:
  - 
- Acceptance Criteria:
  1. 
  2. 
- Test Plan:
  1. 
  2. 
- Done Definition:
  1. Acceptance criteria are satisfied.
  2. Test plan was executed and evidenced.
  3. `./scripts/check.sh --stack <python|node|go>` exits with code `0`.
- Notes:
  - 

## Completion Checklist
- [ ] All task acceptance criteria are met.
- [ ] All task test plans were executed.
- [ ] `scripts/check.sh` passed.
- [ ] Follow-ups (if any) were captured.
