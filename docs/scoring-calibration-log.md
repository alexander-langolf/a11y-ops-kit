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

## Batch ah-1 — addendum 2026-04-17 (post-session review)

### Batch

- Repo: Multiverse-io/account_hub
- Batch: ah-1
- Date: 2026-04-17 (review of 2026-04-16 session)
- Reviewer version: 0.3.0 → 0.3.1 as a result of this review
- Supervisor version: 0.3.0 → 0.3.1 as a result of this review
- Developer version: 0.2.0 → 0.2.1 as a result of this review

### Observations

- **CircleCI log retrieval gap (#829):** Reviewer v0.3.0 continuity policy said "exhaust available tooling" and listed `gh run list` / `gh run view --log-failed` as the exhaustive path. Those tools do not work on external CircleCI checks (`ci/circleci:*`). When CIRCLECI_TOKEN was unset and the CircleCI API returned 401/404, the reviewer fell back to local CI-order reproduction — the right move, but not documented as acceptable. This pushed a well-evidenced failure into `ci_failure_owner: unknown` when the evidence pointed clearly to a pre-existing order-dependent backend flake on unrelated files.
- **Developer scope creep (#829):** Developer fixed pre-existing order-dependent backend test flakes (replaced `deleteMany()` with per-test cleanup, added `@vitest-environment node` directives). The a11y change only touched `RegionSelect.tsx`. Profile v0.2.0 said "only modify test files," which was obeyed literally, but the mission is "fix tests broken by the a11y change," not "fix test infrastructure." This is scope creep driven by an ambiguous profile.
- **Developer dispatched for `ci_failure_owner: unknown`:** Supervisor v0.3.0 only routed `ads` to the developer agent. Sasha explicitly asked to "Spawn developer to fix 829" even though ownership was `unknown`. The supervisor had no guardrail and complied. That direct path allowed the scope-creep fix above to land.
- **Branch update after reviewer flagged BEHIND (#816) worked as designed.** Sasha triggered Ada to rebase; reviewer re-dispatched on fresh head `61d648f2`; CircleCI lint failure correctly diagnosed to `ada` via browser-authenticated fetch. No calibration issue.
- **Head SHA truncation surfaced (#829 re-review):** Developer reported head SHA `9c7823a9f5c9c1bf6d5bba8098afc8799854c197`; GitHub reported `9c7823ae41b42ba6921a0213a0ec586b76e3c483`. Same prefix, different suffix. Likely a race with a new push or a partial-SHA copy-paste. Reviewer logged correctly as a Decision Under Uncertainty and trusted the GitHub value. No action required, but worth keeping under observation.

### Changes Agreed

- Reviewer profile v0.3.1: split `BEHIND` vs `DIRTY` in branch freshness check; add CircleCI API path with `CIRCLECI_TOKEN`; endorse local CI-order reproduction as defensible fallback evidence; add preference for `unknown` over `ads` default when failures are on files unrelated to the PR diff.
- Supervisor profile v0.3.1: loosen pane healthcheck to 5 min nudge / 10 min kill; add `resolve-conflict` routing for DIRTY branches; add guardrail refusing to dispatch developer for `ci_failure_owner: unknown` without explicit Sasha confirmation; remove `handoff()` from tool list.
- Developer profile v0.2.1: add explicit out-of-scope list (pre-existing flakes, test env directives, cleanup rewrites, unrelated backend tests); require `NEEDS_HUMAN` when failing test file is not touched by the a11y change and does not reference the a11y-changed element.
- Merge assistant v0.2.0: trust-phase precondition requires `human_reviewed: true` per PR in Batch 1 and Batch 2–3 for ORANGE/RED.
- Repo config: added `circleci_token_env` and `baselines_verified` keys; monitor flows gate on `baselines_verified: true`.

### Evidence

- PRs reviewed: 6 in batch ah-1 with dev fix touches on #822 and #829, reviewer re-dispatches on #816 and #829.
- False PASS examples: n/a this session (phase-1 FLAG discipline from v0.3.0 held).
- Scope creep: #829 developer commit `9c7823a9f5c9c1bf6d5bba8098afc8799854c197` modified 4 files outside the a11y change's blast radius.
- Production regressions: n/a (no merges from this batch yet).

---

## Batch ah-1 — original entry

### Observations

- **PASS + human-triage contradiction (4 PRs: #821, #828, #830, #825):** Reviewers issued `verdict: PASS` alongside `next_action: human-triage`, with notes stating "Batch ah-1 is repo calibration, so human review is still required despite PASS." The rubric maps PASS → merge-ready, so PASS+human-triage is self-contradictory and breaks supervisor routing. A scored PR that requires human sign-off should use `verdict: FLAG` (ORANGE tier or above), or the rubric needs an explicit trust-phase-1 override that the reviewer can apply cleanly. As-is, the supervisor had to override the verdict field to route these correctly.
- **No miscalibration on CI triage:** Ada/ads/unknown ownership classification was consistent and evidence-cited across all 19 PRs.
- **Pre-existing repo lint cluster (#816, #820, #824, #827, #829):** Five PRs were blocked by the same `@typescript-eslint/await-thenable` failures in `src/actions.ts`, `src/app/api/trpc/[trpc]/context.ts`, `src/components/WithAuth.tsx`. Reviewers correctly identified these as pre-existing and escalated to unknown. No calibration issue, but worth tracking as a repo-health blocker.

### Changes Agreed

- Threshold changes: none
- Heuristic changes: none
- Template changes: In trust phase 1, reviewers should use `verdict: FLAG` (not PASS) for any PR requiring human sign-off before merge, regardless of tier. PASS should only be used when a PR is genuinely merge-ready under the current trust phase.
- Follow-up actions: Update reviewer prompt to clarify PASS vs FLAG in phase 1.

### Evidence

- PRs reviewed: all 19 in batch ah-1
- False PASS examples: #821, #825, #828, #830 (PASS issued but human-triage required — should be FLAG)
- Follow-up PRs after re-audit: n/a
- Production regressions: n/a

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
