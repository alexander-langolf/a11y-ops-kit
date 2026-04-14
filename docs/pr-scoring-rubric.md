# PR Scoring Rubric

Version: `0.1.0`
Status: `target review policy to implement`

Audience: ADS reviewer agents, CAO supervisor, ADS operators

Purpose: Every Workback accessibility remediation PR must pass CI triage before scoring. After the current head SHA is green, the reviewer agent grades the PR across 6 dimensions. The score determines whether the PR is auto-merge eligible, agent-review only, or escalated for human review.

This document is the canonical review policy for this repo.

## CI Merge Gate

Every Workback remediation PR must clear CI triage before it can be scored.

| State | Reviewer action |
| --- | --- |
| Checks pending / in progress | WAIT. Re-check later. Do not score yet |
| Any PR CI job red, failed, or cancelled on the current head SHA | Diagnose ownership first. If `ada`, return `CI_BLOCKED`. If `ads`, route to the ADS test-fix workflow and re-review on the new head SHA. If `unknown`, escalate for human triage. Do not score yet |
| All PR CI jobs green on the current head SHA | Proceed to numeric scoring |

Rules:

- There is no "pre-existing red but safe to merge" path in this workflow.
- Reviewer agents do not treat `[skip ci]`, path-filter skips, or `benchmarkonly` conventions as valid shortcuts for Workback remediation PRs.
- CI triage is a merge gate, not a risk signal.
- `CI_BLOCKED` is reserved for Ada-owned failures.
- `ads` and `unknown` failures remain unscored until re-review or human triage completes.

## Scoring Model

Scoring starts only after the current head SHA passes CI triage.

### 1. Diff Scope (0-3)

| Score | Condition |
| --- | --- |
| 0 | 1 file, under 20 lines changed |
| 1 | 2-3 files, or 20-50 lines |
| 2 | 4-5 files, or 50-100 lines |
| 3 | 6+ files, or 100+ lines, or touches config / routing / auth files |

### 2. Fix-Issue Alignment (0-3)

| Score | Condition |
| --- | --- |
| 0 | Diff clearly matches the stated WCAG criterion and issue description |
| 1 | Matches but uses an unusual or non-standard approach |
| 2 | Partially matches; includes extra changes beyond the stated issue |
| 3 | Does not match, addresses a different issue, or includes unrelated modifications |

### 3. Test Completeness (0-3)

| Score | Condition |
| --- | --- |
| 0 | All related test files updated and assertions match the new DOM |
| 1 | Tests exist but were not updated |
| 2 | Test files in the same directory reference changed elements but were untouched |
| 3 | Test files removed without justification |

### 4. Side Effect Risk (0-3)

| Score | Condition |
| --- | --- |
| 0 | Pure attribute addition such as `aria-*`, `role`, `tabindex` |
| 1 | DOM restructuring such as heading levels, landmarks, wrappers |
| 2 | CSS or style changes, or component prop changes |
| 3 | Touches business logic, auth, routing, state management, or i18n |

### 5. Convention Compliance (0-2)

| Score | Condition |
| --- | --- |
| 0 | Follows repo rules and project conventions |
| 1 | Minor deviation such as a non-standard selector or missing reasoning trace |
| 2 | Major deviation such as fragile selectors, hardcoded strings, or removed functionality |

### 6. Historical Signal (0-2)

| Score | Condition |
| --- | --- |
| 0 | First occurrence of this pattern, or clean history |
| 1 | Similar pattern was FLAGged in a previous batch |
| 2 | Similar pattern caused a FAIL, follow-up PR after Workback re-audit, or production regression previously |

## Escalation Tiers

| Score Range | Tier | Meaning |
| --- | --- | --- |
| 0-3 | GREEN | Auto-merge eligible |
| 4-7 | YELLOW | Agent review sufficient, batch approval required |
| 8-11 | ORANGE | Agent flags specific concerns, human must review |
| 12-16 | RED | Human reviews the full diff before any action |

Single-dimension override:

- Any dimension scoring its maximum forces at least YELLOW, even if the total is below 4.
- A PR is only truly GREEN when the total is `0-3` and no single-dimension override fires.

## Verdict Mapping

| State | Verdict | Meaning |
| --- | --- | --- |
| CI merge gate pending, or ADS / unknown remediation is still in progress | WAIT | Do not score yet |
| CI triage identified an Ada-owned failure | CI_BLOCKED | Return to Ada. Not scoreable, not mergeable |
| GREEN or YELLOW with no blocking correctness concern | PASS | Mergeable under the current trust phase |
| ORANGE, or any scored PR that needs human judgment before merge | FLAG | Human review required before action |
| Incorrect fix, unrelated modifications, or scored risk that should be returned to Ada | FAIL | Do not merge. Return with specific comments |

## Trust Phase Integration

Each repo starts in Batch 1 regardless of trust level in other repos.

`Auto-merge` below means eligible for the prepared merge set without extra human diff review. Sasha still launches the merge assistant unless a later automation step removes that manual launch.

| Phase | Auto-merge | Agent-only | Human required | Trigger to advance |
| --- | --- | --- | --- | --- |
| Batch 1 | None | None | All | None |
| Batch 2-3 | None | GREEN (0-3) | YELLOW+ (4+) | Batch 1: 0 regressions |
| Batch 4+ | GREEN (0-3) | YELLOW (4-7) | ORANGE+ (8+) | Batches 2-3: under 5 percent false PASS rate |
| Mature | GREEN + YELLOW (0-7) | ORANGE (8-11) | RED (12-16) | 100+ PRs with under 2 percent false PASS rate |

The CI triage gate applies in every phase before tier evaluation.

False PASS rate definition:

- Percentage of agent `PASS` verdicts later overturned by human review, follow-up PR after Workback re-audit, or confirmed production regression.

## Output Templates

See:

- [`../templates/pr-comments/ci-blocked.md`](../templates/pr-comments/ci-blocked.md)
- [`../templates/pr-comments/score-card.md`](../templates/pr-comments/score-card.md)
- [`../templates/pr-comments/batch-summary.md`](../templates/pr-comments/batch-summary.md)

## Reviewer Workflow

1. Run `gh pr checks {number}` for the current head SHA.
2. If checks are pending, wait and re-check.
3. If any PR CI job is red, failed, or cancelled, diagnose ownership first.
4. If the failure is `ada`-owned, post the CI-blocked comment and return `CI_BLOCKED`.
5. If the failure is `ads`-owned, return `WAIT` plus the failure details so the supervisor can route to the ADS test-fix workflow.
6. If ownership is `unknown`, return `WAIT` plus escalation notes for human triage.
7. Only after all PR CI jobs are green on the current head SHA should the reviewer compute the score.
8. Post the score card comment.
9. Return a structured result to the CAO supervisor.

## Heuristics

### Side Effect Risk by File Path

| Path pattern | Default score |
| --- | --- |
| Only `aria-*`, `role`, `tabindex` additions | 0 |
| Heading level changes, landmark wrappers | 1 |
| `.css`, `.scss`, `.module.css`, layout-affecting class changes | 2 |
| `**/auth/**`, `**/routes/**`, `**/config/**`, `**/middleware/**`, `**/*.config.*` | 3 |
| `**/api/**`, `**/trpc/**`, `**/graphql/**`, `**/relay/**` | 3 |

### Test Completeness Detection

1. Get the list of changed files from the diff.
2. For each changed component file, inspect the same directory for `*.test.*` and `*.spec.*`.
3. Check whether those tests reference the changed element or DOM contract.
4. If a related test exists and was not updated, score accordingly.

### Red-CI Ownership Triage

1. Read the failing job output before assigning ownership.
2. Classify `ads` when the implementation appears correct but tests, snapshots, or queries still assert the old DOM, label, string, or heading level.
3. Classify `ada` when the remediation change itself appears broken or inconsistent with the intended DOM.
4. Classify `unknown` when the failing logs do not support confident ownership.

Example:

- Heading `h3` -> `h2` in component code, with failing tests still asserting `getByRole("heading", { level: 3 })`, is an `ads`-owned failure that needs test updates before re-review.

### Fix-Issue Alignment Detection

1. Parse the PR title and body for the WCAG criterion.
2. Parse the diff for the type of change made.
3. Cross-reference the change type against the WCAG criterion family.

Examples:

- `4.1.2` -> ARIA attributes, roles, labels
- `1.3.1` -> semantic HTML, headings, landmarks
- `2.4.7` -> focus styles and outlines
- `1.1.1` -> alt text, image labeling
- `1.4.11` -> color or contrast CSS changes

## Calibration

Batch 1 is the calibration batch for a new repo:

1. Agent scores every PR with this rubric.
2. The ADS lead reviewer manually reviews every PR independently.
3. Compare agent scores with the ADS lead reviewer's actual verdicts.
4. Adjust thresholds or heuristics when necessary.
5. Record changes in [`./scoring-calibration-log.md`](./scoring-calibration-log.md) and `CHANGELOG.md`.
