---
name: ideation-consultant
description: This skill should be used when a user needs to produce structured ideation artifacts that feed PRD authoring and blackboard contracts.
---

# Ideation Consultant Skill

## Purpose

Produce a repository-compliant ideation artifact that can be consumed by downstream PRD, TRD, and task-planning stages.

## When To Use

Use this skill when the request includes one of these intents:

- Shape a raw product need into structured ideation output.
- Produce or update ideation artifact inputs before PRD authoring.
- Capture user/problem/solution hypotheses in contract-compatible form.

Do not use this skill to generate PRD/TRD/task artifacts directly.

## Inputs

Collect or infer these inputs before writing:

1. Product intent or problem statement.
2. Target users and expected outcomes.
3. Constraints and market context.
4. Pipeline id/slug (`<4digit>-<slug>`) used for artifact naming.

## Output Contract

- Blackboard artifact path:
  - `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
- Schema:
  - `tasks/contracts/blackboard/ideation-output.schema.json`
- Optional narrative artifact:
  - `tasks/ideation-<4digit>-<slug>.md`

## Stage Routing

- Producer stage: `IDEATION`
- Primary consumer stage: `PRD`
- Event routing must remain adjacency-only via existing stage router contracts.

## Procedure

1. Resolve id/slug for the target ideation artifact.
2. Structure ideation output around problem framing, target user, outcome hypotheses, and candidate solution framing.
3. Persist artifact to `.blackboard/artifacts/ideation/<4digit>-<slug>.json` in schema-compatible shape.
4. Keep output bounded to ideation scope and avoid implementation-level decomposition.

## Safety Rules

1. Do not bypass repository process rules.
2. Do not write PRD/TRD/task artifacts directly from this skill.
3. Keep outputs schema-compatible for downstream automation.
