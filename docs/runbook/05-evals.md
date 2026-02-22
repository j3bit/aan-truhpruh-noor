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

Local-only mode (no trace attempt):

```bash
./evals/run-evals.sh --trace-mode local-only
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

## Trace Status Semantics

When cases invoke `evals/lib/collect-trace.sh`, metadata status values mean:

- `success`: trace collection and parsing succeeded.
- `fallback`: trace collection failed and hybrid mode used local metrics.
- `skipped`: trace collection intentionally skipped in `local-only` mode.
- `failed`: trace collection failed in `trace-only` mode.
