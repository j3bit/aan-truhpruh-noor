# PR Review Contract Reference

Use this reference to keep review output aligned with repository process and review standards.

## Input Contract

Preferred review inputs:

1. Diff artifact (PR diff, patch text, or git comparison range).
2. Base and head context (for deterministic changed-file scope).
3. Optional linked artifacts for intent validation:
   - `tasks/prd-<4digit>-<slug>.md`
   - `tasks/tasks-<4digit>-<slug>.md`

If input is incomplete, recover scope from local git before requesting clarification.

## Required Review Priorities

Review priorities in order:

1. Correctness bugs
2. Behavioral regressions
3. Missing or weak tests
4. Security and trust-boundary issues
5. Data integrity and compatibility risks

De-prioritize style-only comments unless they hide a functional risk.

## Output Contract

Required output order:

1. Findings (highest severity first)
2. Open questions or assumptions (if any)
3. Brief summary (optional, after findings)

Each finding should include:

1. File path (line reference when available)
2. Severity
3. Impact/risk explanation
4. Suggested correction direction

If there are no actionable findings:

- explicitly state no findings
- include residual risks/testing gaps

## Repository Alignment

The repository expects review behavior consistent with:

- `AGENTS.md` non-negotiable rules
- diff-first review discipline
- untrusted external input handling

For this skill, the practical interface is:

- Input: diff
- Output: review comments

## Practical Commands

Collect changed files:

```bash
git diff --name-only <base>...<head>
```

Collect scoped patch:

```bash
git diff --unified=3 <base>...<head>
```

Local staged review:

```bash
git diff --staged
```
