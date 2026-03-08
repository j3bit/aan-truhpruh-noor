---
name: develop-concept
description: This skill should be used when a user needs to turn ambiguous product intuition into a Lean Product Concept and ideation blackboard artifacts that can be consumed by create-prd.
---

# Develop Concept Skill

## Purpose

Lead the ideation stage as a Business Architect and Cognitive Midwife.
Extract core value from ambiguous intuition, convert it into market language, and produce decision-ready concept artifacts that `create-prd` can consume without misinterpretation.

## When To Use

Use this skill when a request includes one of these intents:

- Shape a raw idea into a product concept.
- Run discovery dialogue before PRD authoring.
- Produce ideation outputs for the `IDEATION -> PRD` stage handoff.
- Create or update ideation artifacts under `.blackboard/artifacts/ideation/` or `tasks/ideation-*.md`.

Do not use this skill to write PRD/TRD/task/DAG artifacts directly.

## Inputs

Collect or infer these inputs before writing outputs:

1. Initial product intuition, opportunity, or problem statement.
2. Target user candidates and market context.
3. Constraints (technical, legal, organizational, timeline, budget).
4. Pipeline id/slug (`<4digit>-<slug>`) for artifact naming.

If id/slug is missing, derive them from repository state and idea summary.

## Output Contract

Produce both artifacts in the same run:

1. Markdown concept artifact:
   - `tasks/ideation-<4digit>-<slug>.md`
2. Blackboard ideation artifact:
   - `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
   - must validate against `tasks/contracts/blackboard/ideation-output.schema.json`

Markdown output must use this fixed section order (Lean Product Concept / `product_concept.md` format):

1. `Product Identity`
2. `Target & Problem`
3. `Value Proposition`
4. `Key User Journey`
5. `Constraints & Out of Scope`

Use `references/concept-contract.md` for JSON field requirements and section-to-field mapping.

## Procedure

1. Clarify intent with staged Q&A:
   - start from problem signal, target user, and urgency
   - probe existing alternatives and structural limitations
   - test value hypothesis and differentiation
2. Converge concept when ambiguity is materially reduced:
   - convert abstract statements into observable outcomes
   - separate goals from exclusions
3. Write Markdown artifact at `tasks/ideation-<4digit>-<slug>.md` using the fixed five-section format.
4. Serialize equivalent JSON artifact at `.blackboard/artifacts/ideation/<4digit>-<slug>.json` using schema-compliant keys.
5. Preserve stage routing contract:
   - Producer stage: `IDEATION`
   - Consumer stage: `PRD`
   - keep adjacency-only routing assumptions
6. Keep scope bounded:
   - move speculative expansions into `Constraints & Out of Scope`
   - record unresolved items as explicit assumptions

## Completion Conditions

Mark ideation complete only when all conditions are true:

1. Both markdown and JSON artifacts exist at contract paths for the same `<4digit>-<slug>`.
2. Markdown has all five required sections with concrete content.
3. JSON conforms to `tasks/contracts/blackboard/ideation-output.schema.json`.
4. Output is ready for downstream `create-prd` without additional interpretation.

## Safety Rules

1. Do not bypass `tasks/process-rules.md`.
2. Do not write PRD/TRD/task/DAG artifacts directly.
3. Keep ideation outputs schema-compatible and stage-compatible.
4. Do not bypass adjacency constraints in stage routing.
