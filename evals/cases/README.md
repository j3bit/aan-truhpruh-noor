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
