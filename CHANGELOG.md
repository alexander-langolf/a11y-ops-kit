# Changelog

## 0.3.0 - 2026-04-17

Post-session review of `cao-a11y-phase0` / batch `ah-1`. Addresses skill-file drift, developer scope creep on #829, supervisor missing a guardrail for `ci_failure_owner: unknown`, CircleCI log retrieval gap, and monitor flows running on placeholder baselines.

### Skill-file consolidation

- Deleted duplicate stale copies `skills/cao-workback-supervisor.md` and `skills/cao-workback-reviewer.md` that shared frontmatter names with the canonical `a11y-*` files and created CAO resolution ambiguity.
- Renamed `skills/cao-workback-developer.md` → `skills/a11y-developer.md` and `skills/cao-merge-assistant.md` → `skills/a11y-merge-assistant.md` so filenames match their `name:` frontmatter.
- Updated `skills/README.md` profile table to reflect the four canonical filenames.

### Reviewer v0.3.0 → v0.3.1 (`skills/a11y-pr-reviewer.md`)

- Step 0 branch freshness now splits `BEHIND` (`next_action: update-branch`, `branch_status: outdated`) from `DIRTY` (`next_action: resolve-conflict`, `branch_status: conflicted`). `BLOCKED` is no longer treated as a freshness problem.
- Continuity policy adds a CircleCI route: check `CIRCLECI_TOKEN`, query the CircleCI v2 API when available, and endorse local CI-order reproduction as defensible fallback evidence.
- Ownership classification prefers `unknown` over `ads` when failures are on files unrelated to the PR diff, to avoid sending the developer after unrelated breakage.
- Result format adds `conflicted` to Branch Status enum and `resolve-conflict` to Next action enum.

### Supervisor v0.3.0 → v0.3.1 (`skills/a11y-review-supervisor.md`)

- Pane healthcheck thresholds loosened from 3 min nudge / 6 min kill to 5 min nudge / 10 min kill to accommodate CircleCI log retrieval and local CI reproduction.
- Added `resolve-conflict` routing: PRs with conflicted branches land on a dedicated conflicted-branch list and never auto-re-dispatch the reviewer.
- Added guardrail: never dispatch `a11y_developer` when `ci_failure_owner: unknown` without explicit Sasha confirmation.
- Removed `handoff()` from the Available MCP Tools list (reserved, not used).
- Batch summary includes Conflicted Branches alongside Outdated Branches.

### Developer v0.2.0 → v0.2.1 (`skills/a11y-developer.md`)

- Explicit scope: only fix test failures that directly track DOM, string, selector, or snapshot changes made by the a11y fix.
- New out-of-scope list: pre-existing flakes, test environment directives added to unrelated files, test-database cleanup rewrites on files the a11y change did not touch, and backend test assertions unrelated to a11y.
- New constraint: never modify a test file that the a11y change did not already break; return NEEDS_HUMAN.

### Merge Assistant v0.1.0 → v0.2.0 (`skills/a11y-merge-assistant.md`)

- Step 0 reads trust phase per invocation and refuses to merge in phase `batch-1` unless each PR entry has `human_reviewed: true`. In phase `batch-2-3` the flag is required for ORANGE/RED tiers.
- Merge log now includes refused PRs as `MERGE_REFUSED` entries rather than silent skips.

### Repo config (`repo-config/README.md`, `account-hub.md`, `ariel.md`)

- New optional keys `circleci_token_env` (name of the env var holding the CircleCI API token) and `baselines_verified` (default `false`).
- Account Hub and Ariel configs set `baselines_verified: false` until real CLS/JS-error-rate baselines are measured from a 7-day quiet window.
- Replaced truncated Datadog dashboard URL in `account-hub.md` with `TBD` and a note.
- Documented `test-and-deploy-workflow` as the CircleCI workflow wrapper aggregating `lint-and-unit-test`, `e2e-test`, and `build-and-scan-image`.

### Monitor flows

- `flows/a11y-monitor-account-hub.flow.md`, `flows/a11y-monitor-ariel.flow.md`, `scheduled/monitor-regression.md`, and `scripts/check-recent-merges.sh` now exit early with `MONITOR SKIPPED — {repo}: {reason}` when `baselines_verified` is not `true`.
- Regression report recommendation lines now link to `docs/rollback-protocol.md` instead of emitting a raw `gh pr revert` command.

### New

- `docs/rollback-protocol.md` — when to revert vs forward-fix, reverse-merge-order default, file-overlap revert groups, stop-the-line on first conflict, post-revert Coda updates.
- Batch-summary template adds `## Outdated Branches`, `## Conflicted Branches`, and `## Decisions` sections.

### Calibration

- Appended a 2026-04-17 addendum to `docs/scoring-calibration-log.md` capturing the CircleCI gap, developer scope creep, missing supervisor guardrail, and a head-SHA race observation.

## 0.2.3 - 2026-04-16

- Supervisor now writes per-PR report files to `reports/{batch_id}/{pr_number}.md` on each agent response.
- Report is written immediately on reviewer result arrival, before routing.
- Developer output and re-review output are appended as separate sections to the same file.
- Final pass at batch close verifies all PR report files exist before producing the batch summary.
- Added `fs_write` to supervisor `allowedTools`.
- Bumped supervisor to 0.2.0.

## 0.2.2 - 2026-04-15

- Synced `docs/specs/2026-04-13-a11y-review-team-design.md` to v0.2.0 with implemented CAO profiles (`skills/`), no-GitHub-comments reviewer policy, batch timing and circuit breaker, Coda contract, developer worktree install guidance, merge assistant branch-protection preconditions, and repo-config optional keys.
- Documented optional `repo-config` fields in `repo-config/README.md` and set `default_branch` / `ci_poll_interval_minutes` on `repo-config/account-hub.md` and `repo-config/ariel.md`.

## 0.2.1 - 2026-04-14

- Removed `File overlap` from reviewer result format and score card template. Overlap analysis is supervisor-only, computed across PRs in the batch. Reviewer reports changed files only.
- Added calibration observation step (step 10) to supervisor workflow. Supervisor now checks worker output for noise or miscalibration and appends findings to `docs/scoring-calibration-log.md`.
- Recorded Phase 0 dry run calibration entry in scoring calibration log.
- Bumped supervisor to 0.1.1, reviewer to 0.1.1.

## 0.2.0 - 2026-04-14

- Converted supervisor and reviewer skill contracts into proper CAO agent profiles with frontmatter.
- Added pre-scoring heuristics to the reviewer profile (test adjacency, string drift, CSS selector, WCAG cross-ref, dependency bump).
- Extended reviewer result format with CI Failure Owner, Next action, Affected routes, Changed files, File overlap.
- Added developer agent profile (`a11y_developer`) for mechanical test fixes on Workback branches.
- Added merge assistant agent profile (`a11y_merge_assistant`) for sequential squash-merge after human approval.
- Added `repo-config/` with static per-repo configuration for Account Hub and Ariel.
- Added `flows/` with CAO monitor flows for Account Hub and Ariel (every 4h on weekdays).
- Added `scheduled/` with Claude Code cloud task spec for always-on regression monitoring.
- Added `scripts/check-recent-merges.sh` for conditional monitor flow execution.
- Updated batch-summary template with RED tier, developer routing, file overlap, and merge ordering.
- Updated score-card template with Changed files, Affected routes, and File overlap fields.
- Updated `skills/README.md` with profile table and versioning policy.
- Updated root `README.md` with new directories, layout table, and glossary.

## 0.1.0 - 2026-04-13

- Bootstrapped the initial A11y Ops Kit repo.
- Added the canonical PR scoring rubric with a hard CI merge gate.
- Added the EM onboarding questionnaire in markdown format.
- Added source-of-truth guidance for Coda, Slack, GitHub, Workback, vault, and this repo.
- Added initial CAO reviewer and supervisor skill contracts.
- Added reusable PR comment templates for CI-blocked, score-card, and batch-summary flows.
