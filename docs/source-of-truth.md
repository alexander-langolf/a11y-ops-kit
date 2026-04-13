# Source Of Truth

This repo exists to version the operating contracts behind the accessibility remediation pipeline. It does not replace Coda, GitHub, Workback, Slack, or the vault.

## System Boundaries

| System | Canonical owner | What belongs there | What does not belong there |
| --- | --- | --- | --- |
| Coda | ADS operations | Issue lifecycle, repo ops rows, batch tracker, blocker log, reporting metrics, follow-up PR links, dates, handoff notes | PR review comments, raw CI logs, long-form strategy docs |
| GitHub | Repo + ADS review loop | PRs, diff history, CI checks, merge history, Ada feedback thread | Batch tracker state, sponsor reporting, Slack-only decisions |
| Workback | Vendor execution | Audit inventory, re-audit outcomes, follow-up remediation attempts, issue-level verification | Merge authority, final code-safety sign-off |
| Slack | Communication layer | Alerts, stakeholder updates, escalation pings, fast coordination | Durable state, issue lifecycle tracking, handoff-only decisions |
| LangolfVault | Working notes | Strategy, brainstorms, planning notes, related context | Canonical automation contracts, active tracker state |
| This repo | Versioned ops kit | Review policy, questionnaires, skill contracts, templates, script specs | Live status, batch state, issue tracker data |

## Hard Rules

1. Coda is the durable operating system for ongoing remediation work.
2. GitHub is the execution layer for code changes and Ada feedback.
3. Workback is the post-merge accessibility verification layer.
4. Slack is a notification and escalation layer only.
5. Decisions made in Slack must be copied into Coda the same day.
6. This repo should not store issue-level operational state.

Public repo note:

- This repo is safe to keep public because it documents operating policy, not live tracker state.
- Private links such as the exact Coda workspace or internal access instructions should live in internal onboarding material, not in this public repo.

## What To Capture In Coda

### Issue Table

- `Status`
- `Batch`
- `PR_URL`
- `Batch_Date`
- `Merged_Date`
- `Verified_Date`
- `Agent_Verdict`
- `Notes`
- `Followup_PR_URL`

### Repo Ops Row

- `Repo`
- `EM`
- `Squad_Contact`
- `ADS_Deputy`
- `CI_Verified`
- `Branch_Protection_Verified`
- `Current_Trust_Phase`
- `Current_Batch`
- `Awaiting_Reaudit_Count`
- `Open_Blocker`
- `Last_Updated`

`CI_Blocked` in Coda means the same operational state as `CI blocked` in batch summaries and templates.

### Batch Tracker Row

- `Batch_ID`
- `Repo`
- `Strategy`
- `PR_Count`
- `GREEN`
- `YELLOW`
- `ORANGE`
- `CI_Blocked`
- `Merged`
- `Awaiting_Reaudit`
- `Verified_Fixed`
- `Followup_PRs`
- `Stop_the_Line`
- `Owner`
- `Notes`

### Blockers / Incident Log

- `Date`
- `Repo_or_Batch`
- `Type`
- `Severity`
- `Summary`
- `Owner`
- `ETA`
- `Status`
- `Link`

## What To Post In Slack

Use Slack for:

- Batch start notifications
- Batch completion notifications
- Weekly progress updates
- Datadog alert traffic
- Urgent regression reports
- Fast context questions to squad contacts

Every Slack update that changes operating state should include a link back to the relevant Coda row or view.

## What To Keep In This Repo

Keep versioned artifacts here:

- Review policy and rubric
- EM onboarding template
- Skill contracts and prompts
- Reusable comment templates
- Script specs and future automation code

## Handoff Check

Another ADS operator should be able to answer these questions without scrolling Slack:

1. Which repos are active right now?
2. Which batch is live for each repo?
3. Which PRs are merged but still awaiting Workback re-audit?
4. Which blockers are open and who owns each one?
5. Which squad contact should be pinged for context or repro help?
6. Which trust phase applies to each repo?

If those answers are not available in Coda, the source-of-truth model is failing.
