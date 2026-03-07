---
name: create-trd
description: This skill should be used when a user needs to transform a repository-compliant PRD into a repository-compliant TRD and TRD blackboard artifact.
---

# Create TRD Skill

## Purpose

Create one repository-compliant TRD and matching TRD blackboard artifact from a PRD while enforcing architecture rigor, contract paths, and gate-safe behavior.

## When To Use

Use this skill when the request includes one of these intents:

- Create a new TRD from an existing PRD.
- Draft or complete `tasks/trd-*.md`.
- Produce `.blackboard/artifacts/trd/*.json` for downstream planning.

Do not use this skill to generate task DAG artifacts or implement product code.

## Inputs

Collect or infer these inputs before writing:

1. Source PRD path (`tasks/prd-<4digit>-<slug>.md`).
2. Repository architecture constraints and process rules.
3. Pipeline id and slug (`<4digit>-<slug>`).

If PRD path is missing, resolve deterministically:

- Inspect `tasks/prd-*.md`.
- If exactly one file exists, use it.
- If multiple files exist, stop and request explicit PRD selection.
- If no file exists, stop and report a blocker.

## Output Contract

- TRD path:
  - `tasks/trd-<4digit>-<slug>.md`
- Blackboard artifact path:
  - `.blackboard/artifacts/trd/<4digit>-<slug>.json`
- TRD source template:
  - `tasks/templates/trd.template.md`
- Artifact schema:
  - `tasks/contracts/blackboard/trd-output.schema.json`

Reference contract details from `references/trd-contract.md`.

## Required Architecture Perspectives

When authoring TRD, ensure all five architecture perspectives are explicit:

1. System context definition:
   - identify internal service/component boundaries
   - identify external system integration boundaries
2. Interface and API contracts:
   - define communication protocols and data exchange formats
   - define intent of major endpoints/interfaces
3. Data architecture:
   - include logical data model expectations
   - include storage selection rationale
   - include consistency and concurrency control strategy
4. Non-functional requirements:
   - specify availability, latency, and scalability targets using concrete numbers or concrete operating strategy
5. Security and resilience:
   - define authentication/authorization approach
   - define SPOF avoidance and failure recovery strategy

## Procedure

1. Inspect existing `tasks/trd-*.md` files to avoid id/slug collision and unintended overwrite.
2. Resolve source PRD path deterministically when omitted.
3. Extract id/slug from PRD filename and reuse for TRD/artifact outputs.
4. Read `tasks/templates/trd.template.md` and preserve structure.
5. Materialize TRD with concrete architecture decisions tied to PRD scope, goals, constraints, and non-goals.
6. Generate TRD blackboard artifact with schema-compatible fields:
   - `id`
   - `slug`
   - `prd_path`
   - `trd_path`
   - `components`
   - `interfaces`
   - `dependency_rules`
   - `created_at`
7. Validate contract compatibility:
   - run `./scripts/validate-contracts.sh --project-dir .` when available
8. If validation fails, revise with bounded fixes and retry.

## Completion Conditions

Mark completion only when all conditions are true:

1. Exactly one target TRD is created or updated at `tasks/trd-<4digit>-<slug>.md`.
2. Exactly one paired TRD artifact is created or updated at `.blackboard/artifacts/trd/<4digit>-<slug>.json`.
3. TRD captures the required architecture perspectives and remains within PRD scope.
4. Artifact fields match `tasks/contracts/blackboard/trd-output.schema.json`.
5. No unrelated files are changed.
6. Contract validation passes (or a blocked reason is recorded if command execution is unavailable).

## Failure And Retry Rules

If generation fails, retry with minimal bounded corrections:

1. Filename mismatch:
   - rename to contract-compliant TRD and artifact paths
2. Missing architecture signals:
   - add explicit context/interface/data/NFR/security details
3. Schema mismatch:
   - fix required fields, formats, and path patterns
4. Scope drift from PRD:
   - move overflow to TRD open questions and keep current TRD bounded

Retry limit: 3 attempts per TRD request.
After the third failure, stop and report:

- failing rule
- attempted fixes
- exact blocker

## Safety Rules

1. Do not write outside `tasks/` and `.blackboard/artifacts/trd/` for TRD creation.
2. Do not bypass repository process rules in `tasks/process-rules.md`.
3. Do not produce task/DAG artifacts; that is handled by `plan-tasks`.
4. Do not mark implementation complete; this skill only produces TRD artifacts.
