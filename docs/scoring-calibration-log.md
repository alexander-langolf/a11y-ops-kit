# Scoring Calibration Log

Use this file to record meaningful calibration changes to the rubric after early batches.

## Template

### Batch

- Repo:
- Batch:
- Date:
- Reviewer version:
- Rubric version:

### Observations

- Where did the agent over-score?
- Where did the agent under-score?
- Which heuristics produced noisy results?
- Which score bands felt too compressed?

### Changes Agreed

- Threshold changes:
- Heuristic changes:
- Template changes:
- Follow-up actions:

### Evidence

- PRs reviewed:
- False PASS examples:
- Follow-up PRs after re-audit:
- Production regressions:

---

## Phase 0 — Dry Run

### Batch

- Repo: Multiverse-io/account_hub
- Batch: ah-0 (dry run)
- Date: 2026-04-14
- Reviewer version: 0.1.0
- Rubric version: 0.1.0

### Observations

- Reviewer reported "File overlap: No overlap with hotspot file AccountSignUpForm.tsx" on PR #823. That file was not in the PR's changed files. The reviewer over-applied the hotspot note from repo config as a per-PR check instead of leaving cross-PR overlap analysis to the supervisor.
- File overlap is only meaningful across 2+ PRs in a batch. In a 1-PR dry run the field was vacuous noise.

### Changes Agreed

- Threshold changes: none
- Heuristic changes: none
- Template changes: removed `File overlap` from reviewer result format and score card template. Overlap is now supervisor-only, computed from reviewer-reported changed file lists across the batch.
- Follow-up actions: added calibration observation step (step 10) to supervisor workflow — supervisor now checks for noise/miscalibration and appends findings to this log.

### Evidence

- PRs reviewed: #823
- False PASS examples: n/a (verdict was correct — PASS/YELLOW with human review required)
- Follow-up PRs after re-audit: n/a
- Production regressions: n/a
