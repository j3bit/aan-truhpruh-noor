# Runbook 05: Evals

## Purpose

Protect process consistency when templates, rules, or automation change.

## How To Run

```bash
./evals/run-evals.sh
```

## Case Authoring

1. Add `*.case.sh` to `evals/cases/`.
2. Keep each case deterministic.
3. Focus on regressions in process behavior (not only code behavior).

## Recommended Signals

- excessive retry loops (thrashing)
- missing expected process artifacts
- unexpected file creation
- gate bypass attempts
