# Runbook 03: Conductor Operating Model

## Parallelization Unit

Parallelize by workspace/branch, not by random task splitting.

## Conventions

1. Branch format: `task/<task-id>-<slug>`.
2. One task per workspace.
3. Parallel only for tasks marked dependency-free.
4. Merge sequence follows dependency order.

## Review Pattern

1. Review each workspace via diff-first process.
2. Resolve conflicts in a dedicated integration workspace if needed.
3. Merge after gate pass only.
