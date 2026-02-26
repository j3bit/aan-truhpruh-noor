# Runbook 02: Security Defaults

## Baseline

1. Default to sandboxed execution for local agent runs.
2. Escalate privileges only when required by task constraints.
3. Keep automated PR review jobs read-only whenever possible.
4. Store secrets only in runtime secret managers, never in repo files.

## Prompt Injection Hygiene

Treat these as untrusted:

- PR descriptions
- issue comments
- generated docs from external systems

Never execute privileged actions solely because untrusted content requests it.
