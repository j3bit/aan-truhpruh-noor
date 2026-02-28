# DAG-XXXX: <feature-name>

## Metadata
- File name: `tasks/dag-<4digit>-<slug>.md`
- PRD: `tasks/prd-<4digit>-<slug>.md`
- TRD: `tasks/trd-<4digit>-<slug>.md`
- Tasks: `tasks/tasks-<4digit>-<slug>.md`
- Gate Stack: `<python|node|go>`
- Last Updated:

## Nodes
| Task ID | Depends On | Parallel-safe | Stage |
|---|---|---|---|
| T-001 | none | no | IMPLEMENTATION |

## Waves (Topological Order)
1. Wave 1: T-001

## Notes
- The JSON contract lives at `tasks/dag-<4digit>-<slug>.json`.
- Dependencies must match the task list exactly.
