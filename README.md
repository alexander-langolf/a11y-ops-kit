# A11y Ops Kit

Versioned operating assets for the Multiverse accessibility remediation pipeline.

This repo is the stable home for:

- PR review policy and scoring
- EM intake and onboarding templates
- CAO reviewer and supervisor skill contracts
- Reusable PR comment templates
- Future automation glue for GitHub, Coda, and Workback

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
| `skills/` | Versioned CAO skill contracts and prompt specs |
| `templates/pr-comments/` | Reusable markdown comment templates |
| `scripts/` | Placeholder area for future automation scripts |
| `CHANGELOG.md` | Version history for rubric and skill updates |

## Working Rules

1. CI must be green before a Workback PR is scoreable or mergeable.
2. Accessibility correctness is verified by Workback after merge via re-audit.
3. Slack is a speed layer, not a source of truth.
4. Decisions made in Slack must be copied into Coda the same day.
5. This repo should not become a second tracker.

## Versioning

- Use git history and tags to version skill and rubric changes.
- Record meaningful operational changes in `CHANGELOG.md`.
- Include the rubric version in reviewer-generated artifacts when practical.

## Glossary

- `Workback`: the vendor platform that audits production, generates remediation PRs, and re-audits after merge.
- `Ada`: Workback's AI remediation agent.
- `CAO`: the agent-orchestration setup used for batch reviewer and supervisor workflows.
- `Model A`: the ADS-led operating mode where squads grant access and provide context, while ADS owns review, merge, and regression handling.
