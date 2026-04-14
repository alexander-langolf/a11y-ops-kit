# A11y Ops Kit

Versioned operating assets for the Multiverse accessibility remediation pipeline.

This repo is the stable home for:

- PR review policy and scoring
- EM intake and onboarding templates
- CAO agent profiles (supervisor, reviewer, developer, merge assistant)
- Per-repo static configuration
- Post-merge monitoring flows and scheduled tasks
- Reusable PR comment templates
- Automation scripts for GitHub, Coda, and Workback

This repo is not a tracker.

Operational state lives elsewhere:

| System | Canonical purpose |
| --- | --- |
| Coda | Issue lifecycle, repo ops rows, batch tracker, blockers, reporting |
| GitHub | PRs, diffs, CI state, merge history, Ada comment loop |
| Workback | Audit source, re-audit outcomes, follow-up fix attempts |
| Slack | Notifications, alerts, escalation pings |
| LangolfVault | Working notes, framework design, brainstorming |
| This repo | Versioned operating contracts for humans and agents |

## Repo Layout

| Path | Purpose |
| --- | --- |
| `docs/pr-scoring-rubric.md` | Canonical review and scoring policy |
| `docs/scoring-calibration-log.md` | Versioned record of rubric calibration changes |
| `docs/em-questionnaire.md` | Markdown intake questionnaire for EM onboarding |
| `docs/source-of-truth.md` | Rules for what lives in Coda, Slack, GitHub, Workback, vault, and this repo |
| `docs/specs/` | Design specs and target-state architecture documents |
| `skills/` | Versioned CAO agent profiles (supervisor, reviewer, developer, merge assistant) |
| `repo-config/` | Static per-repo configuration (CI checks, routes, contacts, Datadog) |
| `flows/` | CAO flow definitions for scheduled monitoring tasks |
| `scheduled/` | Claude Code cloud scheduled task specs |
| `templates/pr-comments/` | Reusable markdown comment templates |
| `scripts/` | Automation scripts (merge checks, Coda sync) |
| `CHANGELOG.md` | Version history for rubric, profile, and operational changes |

## Working Rules

1. CI must be green before a Workback PR is scoreable or mergeable.
2. Accessibility correctness is verified by Workback after merge via re-audit.
3. Slack is a speed layer, not a source of truth.
4. Decisions made in Slack must be copied into Coda the same day.
5. This repo should not become a second tracker.
6. Live state (trust phase, batch status, blockers) lives in Coda, not in repo files.

## Versioning

- Use git history and tags to version skill and rubric changes.
- Record meaningful operational changes in `CHANGELOG.md`.
- Include the rubric version in reviewer-generated artifacts when practical.
- Agent profile versions follow semver (patch/minor/major) per `skills/README.md`.

## Glossary

- `Workback`: the vendor platform that audits production, generates remediation PRs, and re-audits after merge.
- `Ada`: Workback's AI remediation agent.
- `CAO`: CLI Agent Orchestrator — the agent-orchestration framework used for batch review workflows.
- `CAO flow`: a scheduled CAO task defined in `flows/` with cron schedule and conditional execution.
- `Model A`: the ADS-led operating mode where squads grant access and provide context, while ADS owns review, merge, and regression handling.
- `Developer`: the agent that fixes test files broken by correct a11y changes on Workback branches.
- `Merge Assistant`: the agent that executes squash-merge sequences after human approval.
- `Monitor`: the post-merge regression detection system (CAO flows + Claude Code cloud task).
