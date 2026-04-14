# Changelog

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
