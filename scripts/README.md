# Scripts

Automation glue for the a11y review pipeline.

## Current Scripts

| Script | Purpose | Used by |
| --- | --- | --- |
| `check-recent-merges.sh` | Checks for recent Workback merges in a repo; returns JSON for CAO flow template substitution | CAO monitor flows in `flows/` |

## Planned

- `sync-coda` — update issue status to `Awaiting Re-audit` after merge; write `Verified Fixed` or `Follow-up PR Opened` after Workback re-audit
- `export-batch-summary` — generate stakeholder-ready summaries from GitHub + Coda state

## Rules

- Do not store secrets in this repo.
- Use environment variables for tokens and endpoints.
- Scripts must be executable (`chmod +x`).
