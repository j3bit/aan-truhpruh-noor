# Fix Failing Checks Contract Reference

Use this reference to keep check-recovery work aligned with repository rules and gate semantics.

## Input Resolution

Required recovery inputs:

1. Failing command (prefer full command line).
2. Failure output logs (stderr/stdout or CI excerpt).
3. Stack selector context (`--stacks <csv|auto>`) and optional `--project-dir`.

If a command is missing, recover with repository standard gate command:

```bash
./scripts/check.sh --stacks <csv|auto>
```

Optional project-path variant:

```bash
./scripts/check.sh --stacks <csv|auto> --project-dir <path>
```

## Failure Taxonomy

Classify and fix failures in this order:

1. Contract preflight failures (`scripts/validate-contracts.sh` stage)
2. Lint/format failures
3. Type/static analysis failures
4. Compile/build failures
5. Test failures
6. Environment/configuration failures

Always target the first failing signal before addressing downstream failures.

## Minimal-Fix Strategy

For each retry:

1. Apply the smallest edit that resolves the active failing signal.
2. Re-run the nearest relevant check for that signal.
3. Re-run full gate command.

Avoid broad refactors, style-only churn, and multi-domain fixes in one step.

## Gate Exit Contract

`scripts/check.sh` exit semantics:

- `0`: pass
- `1`: check failure
- `2`: configuration/input error

Do not mark recovery complete unless final gate exit code is `0`.

## Evidence Requirements

Capture recovery evidence in concise form:

1. failing command used for reproduction
2. key failure signal summary
3. fix commands executed
4. final passing gate command

If linked task artifacts are in scope, append this evidence to task notes.

## Retry Policy

Retry limit: 3 attempts per request.

Each attempt must:

1. stay bounded to the active failing signal
2. include explicit re-check
3. avoid silent scope expansion

After 3 unsuccessful attempts, stop and report blocker details instead of forcing completion.

## Hard Stop Conditions

Stop and report immediately when blocked by:

1. missing credentials/secrets
2. unavailable mandatory runtime/tooling
3. external dependency outages
4. policy-restricted actions requiring explicit approval
