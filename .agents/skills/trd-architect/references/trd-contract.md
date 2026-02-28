# TRD Contract Reference (Placeholder)

Use this reference to keep TRD output compatible with downstream task-planning contracts.

## Required Artifacts

1. TRD document:
   - `tasks/trd-<4digit>-<slug>.md`
2. Blackboard artifact:
   - `.blackboard/artifacts/trd/<4digit>-<slug>.json`
3. Schema:
   - `tasks/contracts/blackboard/trd-output.schema.json`

## Required TRD Sections

1. Context
2. Architecture Goals
3. Clean Architecture Boundaries
4. Component Catalog
5. Interface Contracts
6. Dependency Graph
7. Test Architecture
8. Rollout Plan

## Stage Contract

1. Output is consumed by `TASK_PLANNING`.
2. Downstream task planning must treat TRD as primary decomposition input.
