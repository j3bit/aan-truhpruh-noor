# PRD Contract Reference

Use this reference to keep generated PRDs compatible with repository validators.

## Path And Naming

- Path pattern: `tasks/prd-<4digit>-<slug>.md`
- Valid examples:
  - `tasks/prd-0001-auth-foundation.md`
  - `tasks/prd-0123-checkout-rollback.md`
- Invalid examples:
  - `tasks/prd-123-feature.md` (id is not 4 digits)
  - `tasks/prd_1234_feature.md` (wrong separators)

## Required Section Signals

Ensure heading text includes these phrases (case-insensitive):

1. `Problem`
2. `Goals`
3. `Non-goals` (or `Non goals`)
4. `Success Metrics`
5. `Constraints`
6. `Test Strategy`
7. `Rollout`

Repository template already includes these headings:

- `tasks/templates/prd.template.md`

## Validation Commands

Contract validation:

```bash
./scripts/validate-contracts.sh --project-dir .
```

Full gate validation (stack required):

```bash
./scripts/check.sh --stack <python|node|go>
```

## Practical Authoring Notes

1. Write measurable goals and success metrics (baseline -> target format).
2. Keep scope boundary explicit with both In Scope and Out Of Scope.
3. Keep rollout section operational:
   - rollout strategy
   - monitoring signals
   - rollback plan
4. Keep open risks and unresolved decisions visible:
   - Risks And Mitigations
   - Open Questions
