# CAO Workback Supervisor

Version: `0.1.0`

Purpose: Coordinate a batch of Workback remediation PR reviews, aggregate reviewer output, apply trust-phase routing, and present the merge-ready set to ADS.

## Inputs

- Repo name
- Batch ID
- Current trust phase
- List of PR numbers in the batch
- Historical signal summary
- Reviewer results for every PR

## Required References

- [`../docs/pr-scoring-rubric.md`](../docs/pr-scoring-rubric.md)
- [`../docs/source-of-truth.md`](../docs/source-of-truth.md)
- [`../templates/pr-comments/batch-summary.md`](../templates/pr-comments/batch-summary.md)

## Workflow

1. Fan out each PR to the reviewer skill.
2. Collect all reviewer results.
3. Split results into:
   - scored PRs by tier
   - CI-blocked PRs
   - WAIT states
4. Apply the trust-phase table from the rubric.
5. Produce a batch summary with:
   - score distribution
   - CI-blocked count
   - merge-eligible count
   - PRs requiring human review
6. Present a clean action list to ADS.
7. After merge, hand off state updates to Coda tracking.

## Constraints

- Do not merge PRs directly.
- Do not override a CI-blocked result.
- Do not convert Slack into tracker state.
- Always preserve the distinction between:
  - merge-ready
  - human review needed
  - awaiting CI recovery
  - awaiting Workback re-audit

## Expected Output

```text
Batch AR-Semantic-3
GREEN: 13
YELLOW: 4
ORANGE: 2
CI_BLOCKED: 1

Action needed:
- Review ORANGE PRs: #3252, #3254
- Return CI-blocked PR to Ada: #3255
- Merge-ready under current trust phase: #3240, #3241, ...
```
