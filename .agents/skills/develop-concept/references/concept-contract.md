# Develop Concept Contract Reference

Use this reference to keep ideation output compatible with downstream `create-prd` and pipeline routing contracts.

## Required Artifacts

1. Markdown concept artifact:
   - `tasks/ideation-<4digit>-<slug>.md`
2. Blackboard ideation artifact:
   - `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
3. Schema:
   - `tasks/contracts/blackboard/ideation-output.schema.json`

## Markdown Format (`tasks/ideation-<4digit>-<slug>.md`)

The markdown artifact must contain exactly these top-level sections in order:

1. `Product Identity`
2. `Target & Problem`
3. `Value Proposition`
4. `Key User Journey`
5. `Constraints & Out of Scope`

## Required JSON Fields

`id` and `slug` identify the pipeline slice, and `created_at` records traceable creation time.

Required top-level JSON shape:

- `id` (`string`, 4 digits)
- `slug` (`string`, kebab-case)
- `product_identity` (`string`)
- `target_problem` (`object`)
  - `persona` (`string`)
  - `pain_point` (`string`)
  - `structural_limitations` (`string`)
- `value_proposition` (`object`)
  - `customer_utility` (`string`)
  - `differentiated_advantage` (`string`)
- `key_user_journey` (`array[string]`)
- `constraints_out_of_scope` (`object`)
  - `constraints` (`array[string]`)
  - `out_of_scope` (`array[string]`)
- `created_at` (`string`, RFC3339 / date-time)

## Markdown-to-JSON Mapping

1. `Product Identity` -> `product_identity`
2. `Target & Problem` -> `target_problem.persona`, `target_problem.pain_point`, `target_problem.structural_limitations`
3. `Value Proposition` -> `value_proposition.customer_utility`, `value_proposition.differentiated_advantage`
4. `Key User Journey` -> `key_user_journey`
5. `Constraints & Out of Scope` -> `constraints_out_of_scope.constraints`, `constraints_out_of_scope.out_of_scope`

## Stage Contract

1. Producer stage: `IDEATION`
2. Primary consumer stage: `PRD`
3. Event flow must remain adjacency-only through existing stage router contracts.
