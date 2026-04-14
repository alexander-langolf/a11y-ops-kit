# Skills

This directory stores versioned CAO agent profiles for the accessibility remediation team.

## Profiles

| File | CAO name | Role | Provider | Purpose |
| --- | --- | --- | --- | --- |
| `cao-workback-supervisor.md` | `a11y_review_supervisor` | supervisor | claude_code (Opus) | Orchestrates batch review, routes results, dispatches workers |
| `cao-workback-reviewer.md` | `a11y_pr_reviewer` | reviewer | codex | Scores one PR for code safety, diagnoses CI failures |
| `cao-workback-developer.md` | `a11y_developer` | developer | codex (Spark) | Fixes test files broken by correct a11y changes |
| `cao-merge-assistant.md` | `a11y_merge_assistant` | developer | claude_code (Sonnet) | Executes squash-merge sequence after human approval |

The Monitor agent does not have a CAO profile here. It exists as CAO flows in `flows/` and a Claude Code cloud task in `scheduled/`.

## Change Policy

1. Update the profile file.
2. Bump the version in its header following semver:
   - Patch: prompt wording tweak
   - Minor: new heuristic, new output field, workflow step change
   - Major: role restructure, scoring model change, new agent added
3. Update any referenced templates or docs.
4. Record the change in `CHANGELOG.md`.
5. Re-calibrate after Batch 1 or whenever the rubric meaning changes.
