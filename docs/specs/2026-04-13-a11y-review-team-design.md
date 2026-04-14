# A11y Review Team — Design Spec

Version: `0.1.0`

## Purpose

Design a CAO-orchestrated agentic team that reviews, fixes, and monitors Workback accessibility remediation PRs across all 13 Multiverse Stardust consumer apps. The team replaces manual per-PR review with a structured, scored, trust-gated process where agents handle the mechanical work and humans make merge decisions.

## Scope

- All 13 Stardust consumer repos (Account Hub, Ariel, Atlas, Aurora, Checker, Client XP, Evidence Management, Guidance Hub, Guide Allocation Engine, Hello App, Platform, Sync Sessions, User Home)
- Workback-generated PRs only (branch pattern `workbackai/fix/*`, author `ada-workbackai`)
- Code safety review, not accessibility correctness (Workback owns a11y verification via post-merge re-audit)

## Team Architecture

Five agents, two-phase local orchestration via CAO, plus a decoupled monitoring layer.

### Agents

| Agent | Profile name | Provider | Role | CAO role |
| --- | --- | --- | --- | --- |
| Supervisor | `a11y_review_supervisor` | `claude_code` (Opus) | Orchestrates batch review, routes results, dispatches workers | `supervisor` |
| Reviewer | `a11y_pr_reviewer` | `codex` | Scores one PR for code safety, diagnoses CI failures | custom `allowedTools` |
| Developer | `a11y_developer` | `codex` (Spark) | Fixes test files broken by correct a11y changes | `developer` |
| Merge Assistant | `a11y_merge_assistant` | `claude_code` (Sonnet) | Executes squash-merge sequence after human approval | `developer` |
| Monitor | n/a (not a CAO profile) | `claude_code` (Sonnet) | Post-merge regression detection | CAO flow + Claude Code cloud task |

### Two-Phase Orchestration

```
Phase 1 — Review (CAO, local)

  Sasha provides: repo, batch ID, PR list, trust phase, WCAG criteria

  Supervisor
    1. Reads repo-config/{repo}.md for CI checks, routes, contacts
    2. assign(a11y_pr_reviewer) x N in parallel
    3. Ends turn, waits for send_message results
    4. Routes results:
       - ci_failure_owner: ada → already commented, add to "return to Ada" list
       - ci_failure_owner: ads → assign(a11y_developer) with failing test details
       - ci_failure_owner: unknown → add to human escalation list
       - verdict PASS → merge-ready list
       - verdict FLAG → human review list
       - verdict FAIL → return to Ada list
    5. Waits for developer results if dispatched
    6. Computes file overlap from reviewer-reported changed files
    7. Produces batch summary
    8. Cleans up worker tmux sessions
    9. Presents action list to Sasha

Phase 2 — Merge (human-triggered)

  Sasha reviews Phase 1 output, approves merge set
  Sasha launches a11y_merge_assistant with ordered PR list

  Merge Assistant
    1. Verifies CI green on each PR before merge
    2. Checks for merge conflicts with current main
    3. Squash-merges each PR sequentially
    4. Logs merge timestamps per PR
    5. Stops on first conflict
    6. Reports merge log

Phase 3 — Monitor (decoupled)

  CAO flow runs every 4h on weekdays (requires cao-server)
    - Script checks for recent Workback merges
    - If merges found, launches monitor agent with templated prompt
    - Queries Datadog, correlates with merge timeline
    - Posts to Slack if regression detected

  Claude Code cloud task as overnight/always-on fallback
    - Same monitoring logic, no local machine dependency
    - Runs on Anthropic infrastructure
```

## Agent Profile Specifications

### Supervisor (`a11y_review_supervisor.md`)

```yaml
---
name: a11y_review_supervisor
description: Coordinates batch review of Workback accessibility remediation PRs across Multiverse apps
role: supervisor
mcpServers:
  cao-mcp-server:
    type: stdio
    command: uvx
    args:
      - "--from"
      - "git+https://github.com/awslabs/cli-agent-orchestrator.git@main"
      - "cao-mcp-server"
---
```

Inputs (from Sasha at launch):
- Repo name and GitHub org
- Batch ID (e.g., `ah-1`, `ariel-1`)
- PR numbers in the batch
- Current trust phase
- WCAG criteria family
- Historical signal notes

Workflow:
1. Load `cao-supervisor-protocols` skill.
2. Get own `$CAO_TERMINAL_ID`.
3. Read `repo-config/{repo}.md` from the a11y-ops-kit clone.
4. `assign(a11y_pr_reviewer)` for each PR with repo config context injected.
5. End turn. Do not run shell commands to wait. Inbox delivery is idle-based.
6. On reviewer results: route by `ci_failure_owner` and `verdict`.
7. For `ads`-owned CI failures: `assign(a11y_developer)` with failing test details and worktree path.
8. Wait for developer results if dispatched.
9. Compute file overlap from reviewer-reported changed file lists.
10. Produce batch summary using `templates/pr-comments/batch-summary.md`.
11. Clean up worker tmux sessions via `cao shutdown --session {session_name}` for each finished worker.
12. Present action list to Sasha.

Constraints:
- Never writes code or reviews diffs directly.
- Never merges.
- Never overrides a `CI_BLOCKED` result.
- Must end turn after dispatching all `assign` calls (idle-based message delivery).
- Include "check for stale worktrees at `/tmp/a11y-fix-*` and remove before creating new ones" in every developer assign message.
- After all workers report back, close their tmux sessions. Do not close own session.
- If a worker has not responded after 10 minutes, log as blocker and close its session.

### Reviewer (`a11y_pr_reviewer.md`)

```yaml
---
name: a11y_pr_reviewer
description: Reviews one Workback remediation PR for code safety and scores it using the rubric
role: reviewer
allowedTools: ["fs_read", "fs_list", "execute_bash", "@cao-mcp-server"]
provider: codex
mcpServers:
  cao-mcp-server:
    type: stdio
    command: uvx
    args:
      - "--from"
      - "git+https://github.com/awslabs/cli-agent-orchestrator.git@main"
      - "cao-mcp-server"
---
```

Note: `allowedTools` overrides `role` — reviewer gets bash (for `gh`, `rg`) and read access but no file writes. Codex uses soft enforcement (system prompt instructions).

Inputs (from supervisor via `assign`):
- Repo, PR number, batch ID, trust phase
- WCAG criteria for the batch
- Historical signal notes
- Repo-specific config: `ci_required_checks`, `branch_pattern`, `pr_author`, route map, known flaky tests
- Callback terminal ID

Workflow:
1. Load `cao-worker-protocols` skill.
2. Run `gh pr checks {number}` for current head SHA.
3. If checks pending: return `WAIT`.
4. If any CI job failed: diagnose why.
   - Parse failing test output via `gh run view`.
   - Classify `ci_failure_owner`:
     - `ada`: the code change itself is broken.
     - `ads`: existing tests assert on old DOM/strings that the a11y fix correctly changed.
     - `unknown`: cannot determine ownership.
   - If `ada`: post CI-blocked comment using `templates/pr-comments/ci-blocked.md`, return `CI_BLOCKED`.
   - If `ads` or `unknown`: return result with `ci_failure_owner` field, do NOT post CI-blocked comment.
5. If CI green: run pre-scoring heuristics, then score.
6. Post score card comment using `templates/pr-comments/score-card.md`.
7. `send_message` structured result to supervisor.

Pre-scoring heuristics (mandatory before scoring):

1. **Test adjacency check**: For every changed component file, `rg` the directory tree for test files referencing changed elements (heading levels, aria attributes, string literals). If related tests exist and were not updated, feed into Test Completeness score.

2. **String drift detection**: When diff contains changed string literals, search test files for the old string value. If found, classify as `ci_failure_owner: ads`.

3. **CSS selector consistency**: When semantic HTML changes, search `.scss`/`.css`/`.module.*` for selectors targeting the old element.

4. **WCAG criterion cross-reference**: Verify change type matches stated criterion.
   - `1.3.1` → semantic HTML, headings, landmarks
   - `1.4.3` → color/contrast CSS
   - `2.4.2` → page title
   - `3.3.1` → error association (aria-describedby)
   - `4.1.2` → ARIA attributes, roles, labels

5. **Dependency bump detection**: If `package.json` in changed files, flag as elevated Side Effect Risk.

Result format:

```
PR #1234
CI Merge Gate: PASS | CI_BLOCKED | WAIT
CI Failure Owner: ada | ads | unknown | n/a
Score: 5/16
Tier: YELLOW
Verdict: PASS
Top risk dimension: Test Completeness
Affected routes: /pathway-admin, /pathway-admin/list
Changed files: PathwayCard.tsx, PathwayAdminList.tsx, PathwayCard.module.scss
File overlap: PathwayCard.tsx shared with PRs #101, #105
Notes: Related test file exists in same directory and was not updated.
```

### Developer (`a11y_developer.md`)

Based on CAO's built-in developer profile. Frontend-focused: React component testing, DOM assertions, CSS module references.

```yaml
---
name: a11y_developer
description: Fixes test files broken by correct accessibility changes on Workback branches
role: developer
provider: codex
mcpServers:
  cao-mcp-server:
    type: stdio
    command: uvx
    args:
      - "--from"
      - "git+https://github.com/awslabs/cli-agent-orchestrator.git@main"
      - "cao-mcp-server"
---
```

Note: `provider: codex` with Spark model. Codex uses soft enforcement for tool restrictions, but `role: developer` grants full access anyway.

Inputs (from supervisor via `assign`):
- Repo, PR number, Workback branch name
- Worktree path (e.g., `/tmp/a11y-fix-3236`)
- Failing test file paths and failure output
- What the a11y change did (heading level change, string change, etc.)
- Callback terminal ID

Workflow:
1. Load `cao-worker-protocols` skill.
2. Check for stale worktrees: `git worktree list | grep /tmp/a11y-fix-` and remove any that match the target path.
3. Create git worktree: `git worktree add {worktree_path} {branch_name}`.
4. Work entirely inside the worktree directory.
5. Read failing test files and the component diff.
6. Identify mechanical fixes:
   - Heading level assertions (`level: 3` → `level: 2`)
   - String literal updates in test expectations
   - Mock component updates (mock renders old element type)
   - Test query selectors targeting old DOM structure
   - Snapshot updates for changed DOM
7. Apply fixes to test files only.
8. Run the specific test suite to verify.
9. Commit: `test: update assertions for a11y {change_type} changes`.
10. Push to the Workback branch.
11. Clean up worktree: `git worktree remove {worktree_path}`.
12. `send_message` result to supervisor.

If any step fails, remove the worktree before reporting failure.

Result format:

```
PR #3236 — Test Fix
Files fixed: PathwayAdminList.test.tsx (3 assertions updated)
Fix type: heading level 3→2 in mock and queries
Tests passing: yes | no
Commit: abc123
Status: READY_FOR_REVIEW | NEEDS_HUMAN
Notes: ...
```

Constraints:
- Only modifies test files. Never touches component code, CSS, config, or business logic.
- All fixes go to human review queue. Never auto-approved.
- If the fix requires understanding business logic or test intent beyond mechanical replacement, return `NEEDS_HUMAN`.
- Never creates new test files. Only updates existing ones.
- Always cleans up worktree on success or failure.

### Merge Assistant (`a11y_merge_assistant.md`)

```yaml
---
name: a11y_merge_assistant
description: Executes squash-merge sequence for approved Workback PRs after human approval
role: developer
provider: claude_code
mcpServers:
  cao-mcp-server:
    type: stdio
    command: uvx
    args:
      - "--from"
      - "git+https://github.com/awslabs/cli-agent-orchestrator.git@main"
      - "cao-mcp-server"
---
```

Inputs (from Sasha, human-triggered):
- Ordered list of PR numbers to merge
- Repo name
- Merge method: squash-merge

Workflow:
1. For each PR in order:
   - Verify CI is still green via `gh pr checks {number}`.
   - Check for merge conflicts with current `main`.
   - If conflict: stop, report which PR conflicts and with what file.
   - Execute `gh pr merge {number} --squash`.
   - Log merge timestamp.
   - Wait for merge to complete before next PR.
2. Produce merge log.

Merge log format:

```
Batch ah-1 — Merge Log
#815 merged at 14:01 UTC — 3 files (AccountSignUpForm.tsx, package.json, yarn.lock)
#823 merged at 14:03 UTC — 1 file (RegionSelect.tsx)
#825 merged at 14:04 UTC — 1 file (FormError.tsx)
STOPPED: #826 conflicts with merged #815 on AccountSignUpForm.tsx
```

Constraints:
- Only merges PRs explicitly listed by Sasha.
- Stops on first conflict. Does not attempt resolution.
- Never approves PRs. Only executes the merge command.
- Logs precise timestamps for monitor correlation.

### Monitor

Not a CAO agent profile. Exists as two complementary artifacts:

**A. CAO flow (`flows/a11y-monitor-{repo}.flow.md`)**

```yaml
---
name: a11y-monitor-account-hub
schedule: "0 */4 * * 1-5"
agent_profile: developer
provider: claude_code
script: ./scripts/check-recent-merges.sh
---
```

Note: uses the built-in `developer` profile (full access including bash for `gh` and API calls). The flow prompt provides all monitoring-specific instructions. A dedicated `a11y_monitor` profile can be created later if the prompt needs profile-level constraints.

Prompt body uses `[[var]]` placeholders filled from script output: `[[repo]]`, `[[merge_summary]]`, `[[datadog_url]]`, `[[baseline_cls]]`, `[[baseline_js_error_rate]]`, `[[slack_channel]]`.

Script returns `{"execute": false, "output": {}}` if no recent Workback merges, skipping the run.

Requires `cao-server` running on Sasha's machine.

**B. Claude Code cloud scheduled task**

Always-on fallback at `claude.ai/code/scheduled`. Runs daily on weekdays. Self-contained prompt clones the a11y-ops-kit repo, reads `repo-config/*.md`, checks for recent merges, queries Datadog. Does not depend on local machine.

### Monitor detection signals

**Metric timeline correlation:**
- Match Datadog RUM metric changes (CLS spike, JS error rate increase, LCP degradation) against merge timestamps from the merge log.
- The merge assistant logs precise per-PR timestamps. A metric change within 15 minutes of a merge implicates that PR.

**Route correlation:**
- Each reviewer reports changed files and affected routes.
- If a regression appears on `/registration` and PR #815 modified `AccountSignUpForm.tsx` (which maps to `/registration`), PR #815 is the suspect.

**Risk score correlation:**
- CLS regressions most likely from Side Effect Risk 2+ PRs (CSS/layout changes).
- JS error spikes most likely from Side Effect Risk 3 PRs (business logic, routing).
- Pure attribute additions (risk 0) are low-probability suspects.

**Revert and hotfix detection:**
- Check for revert commits or PRs touching batch files within 48h of merge.
- Check for hotfix PRs from squad members touching same files.

**Regression report format:**

```
REGRESSION DETECTED
Metric: CLS > 0.15 on /pathway-admin
Onset: 14:12 UTC (7 min after PR #102 merged)
Suspect PR: #102 (Side Effect Risk: 2, CSS change to .pathway-header)
Evidence: route match + timing + risk score
Recommendation: revert PR #102 via `gh pr revert #102`
Confidence: high | medium | low
```

**Behavioral checks (manual, generated as checklist):**

```
Manual Heap check recommended for batch ah-1:
- /registration funnel: compare completion rate 24h before vs after merge
- /registration: check for rage clicks on form inputs
- /region-select: check for drop-offs after RegionSelect changes
```

## Repo Structure

```
a11y-ops-kit/
  docs/
    pr-scoring-rubric.md              # existing — canonical rubric (v0.1.0)
    source-of-truth.md                # existing
    em-questionnaire.md               # existing
    scoring-calibration-log.md        # existing
    specs/
      2026-04-13-a11y-review-team-design.md  # this spec
  skills/
    README.md                         # update with new profiles
    cao-workback-supervisor.md        # REPLACE — proper CAO profile
    cao-workback-reviewer.md          # REPLACE — proper CAO profile
    cao-workback-developer.md         # NEW — CAO profile (was fixer)
    cao-merge-assistant.md            # NEW — CAO profile
  scheduled/
    README.md                         # NEW — explains scheduled task + flow format
    monitor-regression.md             # NEW — Claude Code cloud task spec
  flows/
    README.md                         # NEW — explains CAO flow format
    a11y-monitor-account-hub.flow.md  # NEW — CAO flow for AH monitoring
    a11y-monitor-ariel.flow.md        # NEW — CAO flow for Ariel monitoring
  scripts/
    README.md                         # existing
    check-recent-merges.sh            # NEW — conditional execution script for monitor flow
  templates/
    pr-comments/
      ci-blocked.md                   # existing
      score-card.md                   # existing
      batch-summary.md                # existing
  repo-config/
    README.md                         # NEW — explains per-repo config format
    account-hub.md                    # NEW — AH config (Datadog, routes, contacts)
    ariel.md                          # NEW — Ariel config
  CHANGELOG.md                        # existing — update
  README.md                           # existing — update
```

## Config Resolution

Agent profiles are repo-agnostic. Per-repo context comes from `repo-config/{repo}.md`.

The supervisor reads the config file at batch start and injects relevant sections into each worker's `assign` message. Workers never read config files directly.

| Agent | Config injected by supervisor |
| --- | --- |
| Reviewer | `ci_required_checks`, `branch_pattern`, `pr_author`, route map for changed files, known flaky tests |
| Developer | Branch name, worktree path, repo clone location, test framework conventions |
| Merge Assistant | Merge method, required checks to verify pre-merge, repo name |
| Monitor | Reads config directly (CAO flow script reads `repo-config/`, cloud task clones repo) |

Config file format (`repo-config/{repo}.md`):

```yaml
---
repo: Multiverse-io/account-hub
domain: app.multiverse.io
squad: Trusted Enterprise Platform
em: TBD
squad_contact: TBD
slack_channel: "#a11y-ops-account-hub"
ci_required_checks:
  - test-and-deploy-workflow
branch_pattern: "workbackai/fix/*"
pr_author: ada-workbackai
datadog:
  dashboard: https://app.datadoghq.eu/dashboard/cex-s7u-nk6/...
  service: account-hub
  baseline_cls: 0.1
  baseline_js_error_rate: 0.5
trust_phase: "Batch 1"
current_batch: null
---
```

Body contains: route map, known hotspot files, known flaky tests, and notes.

Config updates: edit file, commit, push. Next supervisor launch picks up changes.

Adding a new repo: copy existing config, fill from EM questionnaire, commit.

## Batch Naming Convention

Lightweight incrementing IDs: `{repo-short}-{sequence}`. Examples: `ah-1`, `ah-2`, `ariel-1`.

Sasha assigns the batch ID when launching the supervisor. The ID appears in all batch summaries, merge logs, Coda entries, and Slack posts.

## Regression Detection Patterns

### Pre-merge (Reviewer)

1. **Test adjacency check** — For every changed component file, search the directory tree for test files referencing changed elements. Highest-value heuristic: would have caught 17/19 Account Hub PRs and Ariel PR #3236.

2. **String drift detection** — When diff contains changed string literals, search test files for old value. If found, classify `ci_failure_owner: ads`.

3. **CSS selector consistency** — When semantic HTML changes, search stylesheets for selectors targeting the old element.

4. **WCAG criterion cross-reference** — Verify change type matches stated criterion family.

5. **Dependency bump isolation** — If `package.json` in changed files, flag elevated Side Effect Risk and recommend merging first.

6. **File overlap detection** (supervisor, from reviewer data) — Cross-reference changed file lists across all PRs in the batch. Flag conflict risk and recommend merge ordering.

### Post-merge (Monitor)

1. **Metric timeline correlation** — Match Datadog metric changes against per-PR merge timestamps.

2. **Route correlation** — Match affected route to PR that modified components on that route.

3. **Risk score correlation** — Narrow suspects by Side Effect Risk score.

4. **Revert and hotfix detection** — Check for reverts or hotfix PRs touching batch files within 48h.

## Scoring Reference

The reviewer uses the canonical rubric at `docs/pr-scoring-rubric.md` (v0.1.0):

- 6 dimensions: Diff Scope (0-3), Fix-Issue Alignment (0-3), Test Completeness (0-3), Side Effect Risk (0-3), Convention Compliance (0-2), Historical Signal (0-2)
- Total: 0-16
- Tiers: GREEN (0-3), YELLOW (4-7), ORANGE (8-11), RED (12-16)
- Single-dimension override: any max forces at least YELLOW
- Verdicts: PASS, FLAG, FAIL, WAIT, CI_BLOCKED
- CI merge gate is a hard blocker, not a scored dimension

## Trust Phase Integration

Each repo starts at Batch 1 regardless of trust in other repos.

| Phase | Auto-merge | Agent-only | Human required | Advance when |
| --- | --- | --- | --- | --- |
| Batch 1 | None | None | All | n/a |
| Batch 2-3 | None | GREEN (0-3) | YELLOW+ (4+) | Batch 1: 0 regressions |
| Batch 4+ | GREEN (0-3) | YELLOW (4-7) | ORANGE+ (8+) | Batches 2-3: under 5% false PASS rate |
| Mature | GREEN + YELLOW (0-7) | ORANGE (8-11) | RED (12-16) | 100+ PRs with under 2% false PASS rate |

## CAO Compliance Notes

These are verified against the CAO documentation at `github.com/awslabs/cli-agent-orchestrator`:

1. **Required frontmatter fields**: `name`, `description`. All profiles include both.
2. **MCP server config**: All 4 CAO profiles include the `mcpServers` block with `type: stdio`, `command: uvx`, `args` pointing to `cao-mcp-server`.
3. **Role and tool restrictions**:
   - Supervisor: `role: supervisor` (gets `@cao-mcp-server`, `fs_read`, `fs_list`). Cannot execute bash — file overlap detection moved to reviewer output.
   - Reviewer: `role: reviewer` + `allowedTools: ["fs_read", "fs_list", "execute_bash", "@cao-mcp-server"]`. `allowedTools` overrides `role`. Codex uses soft enforcement.
   - Developer: `role: developer` (full access). Codex uses soft enforcement.
   - Merge Assistant: `role: developer` (full access). Claude Code uses hard enforcement.
4. **Provider values**: `claude_code` and `codex` are valid CAO provider values. Model variants (Opus, Sonnet, Spark) configured via provider CLI settings, not the `provider` frontmatter field.
5. **Idle-based message delivery**: Supervisor prompt explicitly instructs to end turn after dispatching `assign` calls. No busy-waiting.
6. **Assign vs handoff**: All worker dispatch uses `assign` (parallel, non-blocking). Workers return results via `send_message`. No `handoff` used in the default workflow.
7. **Skill loading**: Supervisor loads `cao-supervisor-protocols`. Workers load `cao-worker-protocols`.
8. **Tmux cleanup**: Supervisor closes worker sessions via `cao shutdown --session` after collecting results.
9. **Flow format**: Monitor flows use required fields (`name`, `schedule`, `agent_profile`) plus optional `provider` and `script`. Template variables use `[[var]]` syntax.

## Versioning

Each agent profile carries a version in its header. Versions follow semver:

| Change type | Bump |
| --- | --- |
| Prompt wording tweak | Patch (0.1.0 → 0.1.1) |
| New heuristic, new output field, workflow step change | Minor (0.1.0 → 0.2.0) |
| Role restructure, scoring model change, new agent added | Major (0.1.0 → 1.0.0) |

All changes recorded in `CHANGELOG.md`. Supervisor includes agent versions in batch summaries.

## Rollout Plan

### Phase 0 — Dry run

- Convert spec docs into proper CAO profiles.
- Run supervisor + 1 reviewer against Account Hub PR #823 (simplest: pure `aria-label` addition, CI green).
- Compare agent output against Sasha's manual review.
- Goal: validate profile format, assign/send_message flow, score card output.

### Phase 1 — Account Hub Batch 1 (calibration)

- Run full team against the 6 passing Account Hub PRs.
- Supervisor fans out 6 reviewers in parallel.
- Developer handles `ads`-owned CI failures.
- Sasha manually reviews every PR independently (trust phase: Batch 1).
- Compare agent scores with Sasha's verdicts.
- Record in `docs/scoring-calibration-log.md`.

### Phase 2 — Account Hub Batch 2+

- Trust phase advances if Batch 1 had 0 regressions.
- GREEN PRs become agent-review only.
- Merge assistant handles merge sequence.
- Monitor CAO flow activated for Account Hub.

### Phase 3 — Ariel onboarding

- Complete EM questionnaire.
- Create `repo-config/ariel.md`.
- Set up Datadog dashboard or define available signals.
- Phase 0 dry run against Ariel PR #3238.
- Batch 1 calibration with Ariel-specific thresholds.

### Phase 4 — Remaining 11 repos

- Onboard repos one at a time as EM questionnaires complete.
- Each starts at Phase 0. Reuse calibrated heuristics as starting baselines.

### Success criteria

| Transition | Requirement |
| --- | --- |
| Phase 0 → 1 | Dry run completes, score card is reasonable |
| Phase 1 → 2 | 0 regressions, agent scores within 2 points of manual on 80%+ PRs |
| Phase 2 → 3 | Account Hub running smoothly, no stop-the-line incidents |
| Per-repo Batch 1 → 2 | 0 regressions, 0% false PASS rate |
| Batch 2-3 → 4+ | Under 5% false PASS rate |

### Definition of done for v1.0.0

- All 5 agent profiles stable and calibrated against at least 2 repos.
- Monitor running for all active repos.
- Batch summaries consistently match human judgment.
- Developer handles mechanical test fixes without human intervention on 80%+ of `ads`-owned failures.
- Repo-config files populated for all onboarded repos.
- A second ADS operator could launch and run a batch using only the repo docs.

## Evidence Base

This spec is informed by analysis of actual Workback PRs:

**Account Hub** (19 open PRs, 0 merged):
- 31.6% CI first-pass rate (6/19 green)
- 17/19 PRs touch zero test files — dominant failure mode
- 4 PRs modify `AccountSignUpForm.tsx` — file overlap and merge conflict risk
- 18/19 PRs opened same day — batch-open pattern

**Ariel** (2 open PRs, 0 merged):
- PR #3236: heading h3→h2, `js-tests` failing because `PathwayAdminList.test.tsx` still asserts `level: 3`. Ada updated `PathwayCard.test.tsx` but missed the parent component's test.
- PR #3238: pure `aria-label` addition, all CI green. Single file, zero test impact.

These patterns directly informed the pre-scoring heuristics (test adjacency check, string drift detection) and the developer agent's mechanical fix patterns.
