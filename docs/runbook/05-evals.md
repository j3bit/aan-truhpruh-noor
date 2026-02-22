# Runbook 05: Evals

## Purpose

Protect process consistency when templates, rules, or automation change.

## How To Run

```bash
./evals/run-evals.sh
```

Trace-aware mode options:

```bash
./evals/run-evals.sh \
  --trace-mode hybrid \
  --max-retries 3 \
  --max-loop-count 8 \
  --trace-timeout-seconds 90
```

## Case Authoring

1. Add `*.case.sh` to `evals/cases/`.
2. Keep each case deterministic.
3. Focus on regressions in process behavior (not only code behavior).

## Recommended Signals

- excessive retry loops (thrashing)
- loop count limit breaches
- missing expected process artifacts
- unexpected file creation
- gate bypass attempts
- skill-triggered workflows when trace evidence indicates skill usage

## Result Schema

Each JSONL result record includes:

- `case_id`
- `passed`
- `loop_count`
- `retries`
- `unexpected_files`
- `skill_triggered`
