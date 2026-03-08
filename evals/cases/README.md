# Evals Cases

Add executable eval cases as shell scripts with this naming pattern:

- `*.case.sh`

Example:

```bash
#!/usr/bin/env bash
set -euo pipefail

test -f AGENTS.md
```

Then run:

```bash
./evals/run-evals.sh --profile smoke
```

Built-in profiles for the template suite:

- `smoke`: core contract/bootstrap/registry regressions.
- `orchestration`: `smoke` plus orchestration, QA/static, worker-result, and CI path regressions.
- `full`: `orchestration` plus trace fallback and stress-path regressions.

Inspect the selected cases without executing them:

```bash
./evals/run-evals.sh --profile orchestration --list-cases
```

The runner writes JSONL results to `evals/results/<timestamp>.jsonl` with fields:

- `case_id`
- `passed`
- `loop_count`
- `retries`
- `unexpected_files`
- `skill_triggered`

## Case Environment Contract

The eval runner exports these variables to each case:

- `EVAL_META_PATH`: path where the case may write JSON metadata.
- `EVAL_TRACE_MODE`: one of `hybrid`, `trace-only`, `local-only`.
- `EVAL_TRACE_TIMEOUT_SECONDS`: timeout budget for trace collection.
- `EVAL_MAX_RETRIES`: retry threshold used by the runner.
- `EVAL_MAX_LOOP_COUNT`: loop threshold used by the runner.
- `EVAL_REPO_ROOT`: absolute repository path.
- `EVAL_TRACE_HELPER_DIR`: helper script directory (`evals/lib`).

Optional metadata JSON keys for `EVAL_META_PATH`:

- `loop_count` (number, default `0`)
- `retries` (number, default `0`)
- `skill_triggered` (boolean, default `false`)
- `allow_unexpected_files` (boolean, default `false`)

## Trace Status Semantics

When cases use `evals/lib/collect-trace.sh`, `trace_status` in metadata follows:

- `success`: trace collection and parsing completed.
- `fallback`: trace collection failed and the helper fell back to local metrics (`hybrid` mode).
- `skipped`: trace collection intentionally skipped (`local-only` mode).
- `failed`: trace collection failed in strict `trace-only` mode.
