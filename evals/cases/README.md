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
./evals/run-evals.sh
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
