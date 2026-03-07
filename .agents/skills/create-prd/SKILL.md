---
name: create-prd
description: This skill should be used when a user needs to transform develop-concept ideation artifacts or raw product ideas into a repository-compliant PRD file under tasks/prd-fourdigit-slug.md.
---

# Create PRD Skill

## Purpose

Create one repository-compliant PRD file from ideation inputs while enforcing contract sections, naming rules, and gate-safe behavior.

## When To Use

Use this skill when the request includes one of these intents:

- Create a new PRD from ideation artifacts or an idea/problem statement.
- Draft or complete `tasks/prd-*.md`.
- Prepare PRD before generating TRD and atomic tasks.

Do not use this skill to generate `tasks/tasks-*.md` or to implement product code.

## Inputs

Collect or infer these inputs before writing:

1. Upstream ideation sources in this precedence order:
   - `tasks/ideation-<4digit>-<slug>.md`
   - `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
   - direct user brief (fallback)
2. Goals and non-goals.
3. Success metrics.
4. Constraints (technical/security/timeline/legal).
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

## Ideation-To-PRD Mapping Rules

When ideation artifacts exist, map them before drafting:

1. `Product Identity` / `product_identity` -> Problem framing + top-level goal statement.
2. `Target & Problem` / `target_problem.*` -> Problem section details + Non-goals boundary context.
3. `Value Proposition` / `value_proposition.*` -> Goals and Success Metrics anchors.
4. `Key User Journey` / `key_user_journey` -> Test Strategy scenarios + Rollout sequencing cues.
5. `Constraints & Out of Scope` / `constraints_out_of_scope.*` -> Constraints + Non-goals.

If ideation markdown and JSON conflict, prioritize markdown narrative and record the mismatch in Open Questions.

## Procedure

1. Inspect existing `tasks/prd-*.md` files to avoid id/slug collision.
2. Locate ideation artifacts for the selected id/slug using the input precedence order.
3. If ideation artifacts are unavailable or incomplete, collect missing essentials via concise follow-up questions.
4. Read `tasks/templates/prd.template.md` and preserve its overall structure.
5. Materialize `tasks/prd-<4digit>-<slug>.md` from template.
6. Fill all sections with concrete, testable content using ideation-to-PRD mapping rules.
7. Keep scope bounded:
   - capture out-of-scope items in Non-goals
   - add unresolved decisions in Open Questions
8. Validate contract compatibility:
   - run `./scripts/validate-contracts.sh --project-dir .` when available
9. If validation fails, revise PRD and re-run validation.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target PRD file is created or updated at `tasks/prd-<4digit>-<slug>.md`.
2. All required contract sections are present.
3. Available ideation artifacts were incorporated (or absence was explicitly noted).
4. No unrelated files are changed.
5. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).

## Failure And Retry Rules

If generation fails, retry with minimal bounded corrections:

1. Filename mismatch:
   - rename to `tasks/prd-<4digit>-<slug>.md`
2. Missing required sections:
   - add missing headings and complete content
3. Missing ideation linkage:
   - ingest available ideation artifact or record fallback source explicitly
4. Over-scoped PRD:
   - move extra scope into Non-goals or Open Questions

Retry limit: 3 attempts per PRD request.
After the third failure, stop and report:

- failing rule
- attempted fixes
- exact blocker

## Safety Rules

1. Do not write outside `tasks/` for PRD creation.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not mark downstream implementation as complete; this skill only produces PRD artifacts.
