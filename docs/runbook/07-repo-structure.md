# Runbook 07: Repository Structure

## Goal

Keep generated and converted repositories aligned to a root-product-first layout so product code, process contracts, and automation stay predictable.

## Root-Product-First Policy

1. The repository root (`.`) is the product workspace.
2. Do not introduce a default `services/*` product layout.
3. Keep AI process contracts at the root: `tasks/`, `.agents/`, `.blackboard/`, `.orchestration/`, and `.github/`.
4. Treat `examples/` as template verification assets only.

## Recommended Root Layout

```text
.
├─ apps/
├─ packages/
├─ tests/
├─ docs/
├─ infra/
├─ scripts/
├─ tasks/
├─ .agents/
├─ .blackboard/
├─ .orchestration/
└─ .github/
```

## Responsibility Guide

- `apps/`: deployable applications, services, APIs, workers, frontends
- `packages/`: shared modules, libraries, SDKs, and internal contracts
- `tests/`: integration, end-to-end, and cross-boundary verification
- `docs/`: ADRs, specifications, runbooks, and product/system notes
- `infra/`: environment definitions, deployment assets, observability configuration
- `scripts/`: operational automation, validation entrypoints, local developer tooling
- `tasks/`: PRD/TRD/task/DAG contracts and process rules
- `.agents/`, `.blackboard/`, `.orchestration/`: AI execution policy, runtime coordination, and artifacts
- `.github/`: CI workflows and repository automation

## Guardrails

- Put deployable code under `apps/`, not under ad hoc top-level folders.
- Promote reusable code into `packages/` only when it serves more than one product boundary.
- Keep template maintenance assets separate from product code.
- Do not treat `examples/` as a starting point for active product implementation.
