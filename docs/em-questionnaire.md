# EM Onboarding Questionnaire

Use this template when onboarding a repo into the ADS-led accessibility remediation framework.

Goal:

- Give ADS enough information to operate quickly without repeated back-and-forth
- Keep squad-contact scope narrow and explicit
- Capture only judgment, ownership, access, and non-obvious process details
- Push durable answers into Coda after intake

Legend:

- `Required` = blocks safe onboarding if unanswered
- `Nice to have` = useful but not a blocker
- `Owner` = who should answer first

## Response Template

### 1. Governance And Approval

- [Required][EM] Confirm Model A approval for ADS-led remediation on this repo.
- [Required][EM] Effective date of approval.
- [Required][EM] Name the EM accountable for escalation on this repo.
- [Nice to have][EM] Name any sponsor or stakeholder who should receive batch-completion updates.

### 2. Repo And Scope

- [Required][EM] Canonical GitHub repo URL and default branch.
- [Required][EM] Which production app or domain does this repo cover?
- [Required][EM] Are any Workback findings in this repo intentionally out of scope?
- [Nice to have][EM] Which user flows or surfaces are highest priority?

### 3. People And Slack

- [Required][EM] Primary squad contact for route context and regression repro support.
- [Nice to have][EM] Backup squad contact.
- [Required][EM] Preferred Slack channel or thread for non-urgent updates.
- [Nice to have][EM] Who should be cc'd on batch-completion posts?

### 4. Access And Merge Prerequisites

- [Required][EM] Confirm `design-system-engineers` can be added as reviewer on the repo.
- [Required][EM] List any tokens, package credentials, or access prerequisites Workback or ADS will need.
- [Required][EM] Are there any release-train, deploy, or merge restrictions that affect squash-merge timing?
- [Nice to have][EM] Name the person or team who can unblock credentials fastest if CI fails for access reasons.

### 5. CI And Branch Protection

- [Required][EM] CI provider for PR checks.
- [Required][EM] Exact required checks that must be green before merge.
- [Required][EM] Is CODEOWNERS approval enforced by branch protection?
- [Required][EM] Are there known flaky jobs or suites that ADS should watch closely?
- [Nice to have][EM] Which checks are slowest or most failure-prone in practice?
- [Nice to have][EM] Are there special workflows such as GraphQL / Relay / generated code steps that often trip new contributors?

### 6. Batching And Hotspots

- [Required][EM] Preferred batching strategy if there is one: pattern-first, surface-first, or no preference.
- [Required][EM] Top routes or product surfaces ADS should understand first.
- [Required][EM] Any especially sensitive flows that should be first or last in the rollout?
- [Nice to have][EM] Are there directories or modules with unusually high change risk?

### 7. Third-Party And Product Risk

- [Required][EM] Which third-party widgets, embeds, or vendor-owned surfaces exist in this repo?
- [Required][EM] Who owns escalation for those third-party blockers?
- [Nice to have][EM] Are there areas where product would prefer risk acceptance over rapid remediation?
- [Nice to have][EM] Are there wording or content constraints that affect labels, hints, or accessible names?

### 8. Parallel Work And Freeze Windows

- [Required][EM] Active refactors, migrations, security work, or other parallel changes that may collide with Workback PRs.
- [Required][EM] Upcoming freeze windows or change restrictions.
- [Nice to have][EM] Areas of the codebase where merge conflicts are especially likely.

### 9. Monitoring And Regression

- [Required][EM] Datadog service or RUM identifiers ADS should use for monitors.
- [Required][EM] Where should monitoring alerts land?
- [Required][EM] Who should ADS contact if a regression needs product-context confirmation?
- [Nice to have][EM] Which behavioral metrics or funnels matter most after merge?
- [Nice to have][EM] Existing baselines or thresholds worth knowing.

### 10. Backup And Escalation

- [Required][EM] If the ADS lead reviewer is unavailable during a regression, who should ADS escalate to first?
- [Required][EM] Expected response window for urgent context questions.
- [Nice to have][EM] Timezone or working-hour constraints for the squad contact.
- [Nice to have][EM] Preferred granularity for sponsor reporting.

## What ADS Should Inspect Instead Of Asking

These items should usually be confirmed by ADS through repo inspection rather than asking the EM first:

- Actual workflow file names
- Real required-check names from branch protection
- CODEOWNERS paths
- Presence of AGENTS.md / BUGBOT.md / local conventions
- Test file layout
- Generated-code workflows
- Path filters and CI skip behavior

Ask the EM only when the answer is not visible in GitHub or the repo.

## Squad Contact Boundaries

Squad contact responsibilities:

- Route or feature context
- Ownership clarification
- Regression reproduction help

Squad contact is not responsible for:

- Reviewing Workback PRs
- Merging Workback PRs
- Final CI sign-off
- Accessibility correctness sign-off

## Coda Mapping

Map answers from this questionnaire into Coda after intake:

| Questionnaire topic | Coda destination |
| --- | --- |
| EM, squad contact, ADS deputy | Repo Ops row |
| CI provider, required checks, branch protection verified date | Repo Ops row |
| Current trust phase and current batch | Repo Ops row |
| Route hotspots, strategy notes | Batch Tracker notes or repo notes |
| Access blockers, flaky tests, freeze windows | Blockers / Incident log or repo notes |
| Datadog targets and alert routing | Repo Ops row and monitor setup notes |

## Storage Rule

Use this markdown template for intake and discussion. After the answers are stable, Coda becomes the durable system of record.
