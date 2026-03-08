# Process Rules

These rules govern all implementation work in this repository.

1. **Contract-first**: start from `PRD`, `TRD`, `TASKS`, `DAG`, and `tasks/stacks.json`; do not code from chat alone.
2. **Atomic execution**: run one unblocked task at a time.
3. **Bounded scope**: reject unplanned scope expansion; create a new task instead.
4. **Gate-required completion**: task completion requires `scripts/check.sh` exit code `0`.
5. **Diff-first review**: evaluate code changes before discussion text.
6. **Dependency order**: merge tasks in dependency order.
7. **Parallel isolation**: parallel tasks run in isolated branches/workspaces only.
8. **Reproducible commands**: all checks must be scriptable and committed.
9. **Security defaults**: least privilege, explicit approvals, no secret commits.
10. **Trace logging required**: eval/automation runs must record trace evidence, or explicitly capture why fallback mode was used.
11. **Regression discipline**: on failure, add or update eval/test coverage.
12. **Blackboard state**: orchestration state and integration directives must be persisted under `.blackboard/`.
13. **Stage adjacency**: actor communication is allowed only between adjacent stages in the canonical pipeline.
14. **Strict self-heal relay**: QA feedback must flow `QA -> IMPLEMENTATION -> ORCHESTRATION`; direct QA to ORCHESTRATION is forbidden.
15. **Product-root workspace**: the repository root is the product workspace; keep live product code under `apps/`, `packages/`, `tests/`, and `infra/`, never under `services/*` or `examples/*`.
