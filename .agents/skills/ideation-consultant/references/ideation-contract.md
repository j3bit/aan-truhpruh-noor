# Ideation Contract Reference (Placeholder)

Use this reference to keep ideation output compatible with downstream PRD and TRD authoring stages.

## Required Artifact

- Path: `.blackboard/artifacts/ideation/<4digit>-<slug>.json`
- Schema: `tasks/contracts/blackboard/ideation-output.schema.json`

## Required Fields

1. `id`
2. `slug`
3. `product_story`
4. `problem_statement`
5. `target_users`
6. `goals`
7. `non_goals`
8. `constraints`

## Stage Contract

1. Output is produced by `IDEATION`.
2. Output is consumed by `PRD`.
3. Routing must remain adjacency-only through the stage router.
