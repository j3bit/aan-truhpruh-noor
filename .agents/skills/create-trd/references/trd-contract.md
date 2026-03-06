# TRD Contract Reference

Use this reference to keep generated TRDs compatible with repository validators and downstream task planning.

## Path And Naming

- TRD path pattern:
  - `tasks/trd-<4digit>-<slug>.md`
- Blackboard artifact path pattern:
  - `.blackboard/artifacts/trd/<4digit>-<slug>.json`

Examples:

- `tasks/trd-0001-auth-foundation.md`
- `.blackboard/artifacts/trd/0001-auth-foundation.json`

## Required TRD Coverage

Ensure TRD covers these architecture signals (using template headings and concrete content):

1. Context
2. Architecture Goals
3. Clean Architecture Boundaries
4. Component Catalog
5. Interface Contracts
6. Dependency Graph
7. Data and State
8. Observability and Operations
9. Test Architecture
10. Security and Risk
11. Rollout Plan

Template source:

- `tasks/templates/trd.template.md`

## Required TRD Artifact Schema Fields

Artifact must satisfy `tasks/contracts/blackboard/trd-output.schema.json` and include:

1. `id` (4-digit string)
2. `slug` (kebab-case)
3. `prd_path` (`tasks/prd-<4digit>-<slug>.md`)
4. `trd_path` (`tasks/trd-<4digit>-<slug>.md`)
5. `components` (non-empty string array)
6. `interfaces` (string array)
7. `dependency_rules` (string array)
8. `created_at` (date-time string)

## Validation Commands

Contract validation:

```bash
./scripts/validate-contracts.sh --project-dir .
```

Full gate validation:

```bash
./scripts/check.sh --stack <python|node|go>
```

## Practical Authoring Notes

1. Keep architecture scope aligned to PRD goals/non-goals.
2. Define external boundaries before internal decomposition.
3. Use explicit interface contracts to control coupling.
4. Document data consistency and concurrency approach explicitly.
5. Express NFR targets using measurable numbers where possible.
6. Include resilience and rollback assumptions, not only happy-path design.
