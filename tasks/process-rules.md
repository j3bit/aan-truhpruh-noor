# Process Rules

These rules govern all implementation work in this repository.

1. **Contract-first**: start from `PRD` and `TASKS` files; do not code from chat alone.
2. **Atomic execution**: run one unblocked task at a time.
3. **Bounded scope**: reject unplanned scope expansion; create a new task instead.
4. **Gate-required completion**: task completion requires `scripts/check.sh` exit code `0`.
5. **Diff-first review**: evaluate code changes before discussion text.
6. **Dependency order**: merge tasks in dependency order.
7. **Parallel isolation**: parallel tasks run in isolated branches/workspaces only.
8. **Reproducible commands**: all checks must be scriptable and committed.
9. **Security defaults**: least privilege, explicit approvals, no secret commits.
10. **Regression discipline**: on failure, add or update eval/test coverage.
