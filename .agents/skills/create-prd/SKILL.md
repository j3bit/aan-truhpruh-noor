---
name: create-prd
description: This skill should be used when a user needs to transform a product idea into a repository-compliant PRD file under tasks/prd-fourdigit-slug.md.
---

# Create PRD Skill

## Purpose

Create one repository-compliant PRD file from a product idea while enforcing contract sections, naming rules, and gate-safe behavior.

## When To Use

Use this skill when the request includes one of these intents:

- Create a new PRD from idea/problem statement.
- Draft or complete `tasks/prd-*.md`.
- Prepare PRD before generating atomic tasks.

Do not use this skill to generate `tasks/tasks-*.md` or to implement product code.

## Inputs

Collect or infer these inputs before writing:

1. Feature/problem statement.
2. Goals and non-goals.
3. Success metrics.
4. Constraints (technical/security/timeline).
5. Test strategy.
6. Rollout and monitoring plan.
7. PRD id (4 digits) and slug.

If id/slug is missing, derive them from repository state and idea summary:

- Choose an unused 4-digit id.
- Build a lowercase kebab-case slug.

## Output Contract

- Output path: `tasks/prd-<4digit>-<slug>.md`
- Source template: `tasks/templates/prd.template.md`
- Required section coverage:
  - Problem
  - Goals
  - Non-goals
  - Success Metrics
  - Constraints
  - Test Strategy
  - Rollout

Reference contract details from `references/prd-contract.md`.

## Procedure

1. Inspect existing `tasks/prd-*.md` files to avoid id/slug collision.
2. Read `tasks/templates/prd.template.md` and preserve its overall structure.
3. Materialize `tasks/prd-<4digit>-<slug>.md` from template.
4. Fill all sections with concrete, testable content.
5. Keep scope bounded:
   - Capture out-of-scope items in Non-goals.
   - Add unresolved decisions in Open Questions.
6. Validate contract compatibility:
   - Run `./scripts/validate-contracts.sh --project-dir .` when available.
7. If validation fails, revise PRD and re-run validation.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target PRD file is created or updated at `tasks/prd-<4digit>-<slug>.md`.
2. All required contract sections are present.
3. No unrelated files are changed.
4. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).

## Failure And Retry Rules

If generation fails, retry with minimal bounded corrections:

1. Filename mismatch:
   - Rename to `tasks/prd-<4digit>-<slug>.md`.
2. Missing required sections:
   - Add missing headings and complete content.
3. Over-scoped PRD:
   - Move extra scope into Non-goals or Open Questions.

Retry limit: 3 attempts per PRD request.  
After the third failure, stop and report:

- failing rule
- attempted fixes
- exact blocker

## Safety Rules

1. Do not write outside `tasks/` for PRD creation.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not mark downstream implementation as complete; this skill only produces PRD artifacts.
