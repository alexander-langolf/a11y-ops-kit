# Scripts

Placeholder area for future automation glue.

Expected candidates:

- `sync-coda` or equivalent:
  - update issue status to `Awaiting Re-audit` after merge
  - write `Verified Fixed` or `Follow-up PR Opened` after Workback re-audit
- `merge-batch`:
  - merge the approved PR list sequentially
  - stop on conflicts or unexpected state
- `export-batch-summary`:
  - generate stakeholder-ready summaries from GitHub + Coda state

Do not store secrets in this repo.

Use environment variables for future tokens and endpoints.
