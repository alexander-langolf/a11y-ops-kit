# A11y Review Team — Design Spec

Version: `0.2.0`
Status: `target-state design (aligned to repo profiles in skills/)`

## Purpose

Design a CAO-orchestrated agentic team that reviews, fixes, and monitors Workback accessibility remediation PRs across all 13 Multiverse Stardust consumer apps. The team replaces manual per-PR review with a structured, scored, trust-gated process where agents handle the mechanical work and humans make merge decisions.

This document defines the target workflow and stays aligned with the versioned CAO profile bodies under [`skills/`](../skills/); YAML frontmatter blocks in this spec duplicate those files for readability. The spec does not claim the full system is already live in every consumer repo today.

## Scope

- Target architecture supports all 13 Stardust consumer repos (Account Hub, Ariel, Atlas, Aurora, Checker, Client XP, Evidence Management, Guidance Hub, Guide Allocation Engine, Hello App, Platform, Sync Sessions, User Home)
- Initial rollout and calibration start with Account Hub, then Ariel. Expansion beyond approved repos still requires explicit repo onboarding and operating approval.
- Workback-generated PRs only (branch pattern `workbackai/fix/*`, author `ada-workbackai`)
- Code safety review, not accessibility correctness (Workback owns a11y verification via post-merge re-audit)

## Team Architecture

Five agents, a three-stage operating model, and Coda as the live-state store for active remediation state.

### Agents


| Agent           | Profile name             | Provider               | Role                                                          | CAO role                             |
| --------------- | ------------------------ | ---------------------- | ------------------------------------------------------------- | ------------------------------------ |
| Supervisor      | `a11y_review_supervisor` | `claude_code` (Opus)   | Orchestrates batch review, routes results, dispatches workers | `supervisor` + custom `allowedTools` |
| Reviewer        | `a11y_pr_reviewer`       | `codex`                | Scores one PR for code safety, diagnoses CI failures          | custom `allowedTools`                |
| Developer       | `a11y_developer`         | `codex` (Spark)        | Fixes test files broken by correct a11y changes               | `developer`                          |
| Merge Assistant | `a11y_merge_assistant`   | `claude_code` (Sonnet) | Executes squash-merge sequence after human approval           | `developer`                          |
| Monitor         | n/a (not a CAO profile)  | `claude_code` (Sonnet) | Post-merge regression detection                               | CAO flow + Claude Code cloud task    |


### Three-Stage Orchestration

```
Phase 1 — Review (CAO, local)

  Sasha provides: repo, batch ID, PR list, trust phase, WCAG criteria

  Supervisor
    1. Reads repo-config/{repo}.md for static CI checks, routes, contacts
    2. Reads trust phase and current batch state from Coda
    3. assign(a11y_pr_reviewer) x N in parallel
    4. Ends turn, waits for send_message results
    5. Routes results (apply batch circuit breaker before new dispatches when threshold met):
       - verdict WAIT + ci_state: pending → requeue reviewer after poll interval
       - ci_failure_owner: ada → reviewer returned CI_BLOCKED with notes; add to "return to Ada" list (no automatic GitHub comment unless Sasha pastes from templates)
       - ci_failure_owner: ads → assign(a11y_developer) with failing test details
       - ci_failure_owner: unknown → add to human triage list
       - developer_status: READY_FOR_REVIEW → assign(a11y_pr_reviewer) again on current head SHA
       - developer_status: NEEDS_HUMAN → add to human escalation list
       - verdict PASS → merge-ready list
       - verdict FLAG → human review list
       - verdict FAIL → return to Ada list
    6. Waits for developer or re-review results if dispatched
    7. Computes file overlap from reviewer-reported changed files
    8. Produces batch summary + Coda update payload
    9. Cleans up worker tmux sessions
   10. Presents action list to Sasha

Phase 2 — Merge (human-triggered)

  Sasha reviews Phase 1 output, approves merge set
  Sasha launches a11y_merge_assistant with ordered PR list

  Merge Assistant
    1. Verifies CI green on each PR before merge
    2. Checks for merge conflicts with current default branch (e.g. main)
    3. Squash-merges each PR sequentially
    4. Logs merge timestamps per PR
    5. Stops on first conflict
    6. Reports merge log

Phase 3 — Monitor (decoupled)

  CAO flow runs every 4h on weekdays (requires cao-server)
    - Script checks for recent Workback merges
    - If merges found, launches monitor agent with templated prompt
    - Queries Datadog, correlates with merge timeline
    - Posts to Slack with the relevant Coda link if regression detected

  Claude Code cloud task as overnight/always-on fallback
    - Same monitoring logic, no local machine dependency
    - Runs on Anthropic infrastructure
```

Supervisor owns the review loop. A PR only becomes merge-ready from a fresh reviewer result on the current head SHA. Developer output can request re-review, but it never makes a PR merge-ready by itself.

### Batch timing

- **CI poll interval**: When a reviewer returns `WAIT` with CI still pending, the supervisor requeues that reviewer after a poll interval. Default **3 minutes**; override with optional `ci_poll_interval_minutes` in `repo-config/{repo}.md` frontmatter (see the config file format section below).
- **Worker timeout**: If a worker has not responded after **10 minutes**, log as blocker, close its session, and treat as a failed worker outcome for circuit-breaker accounting.

### Batch circuit breaker

After initial reviewer results (and any follow-up worker results) for the batch, if **≥50%** of PRs in the batch end in `NEEDS_HUMAN`, `ci_failure_owner: unknown`, or worker timeout/blocker, the supervisor **halts further automation** for that batch: stop dispatching new `assign` calls, finish collecting any in-flight messages already delivered, produce a single **“batch halted for triage”** section in the batch summary plus the normal Coda update payload, and present the action list to Sasha. Sasha explicitly resets intent (e.g., narrowed PR list, human triage complete) before the next supervisor run. The 50% threshold is the default; Sasha may tighten or loosen it per repo in run notes until codified in repo-config.

## Agent Profile Specifications

Canonical profile bodies live on disk under `skills/`; CAO `name` in frontmatter is what `assign(...)` uses.

### Supervisor — file [`skills/cao-workback-supervisor.md`](../skills/cao-workback-supervisor.md), CAO `name: a11y_review_supervisor`

```yaml
---
name: a11y_review_supervisor
description: Coordinates batch review of Workback accessibility remediation PRs across Multiverse apps
role: supervisor
provider: claude_code
allowedTools: ["fs_read", "fs_list", "execute_bash", "@cao-mcp-server"]
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

Note: the supervisor needs bash access for CAO and tmux lifecycle commands plus Coda sync helpers. It still does not review diffs or write repo code.

Inputs (from Sasha at launch):

- Repo name and GitHub org
- Batch ID (e.g., `ah-1`, `ariel-1`)
- PR numbers in the batch
- Current trust phase
- WCAG criteria family
- Historical signal notes

Workflow:

1. Get own `$CAO_TERMINAL_ID`.
2. Read static `repo-config/{repo}.md` from the a11y-ops-kit clone.
3. Read current trust phase, current batch, and relevant blocker notes from Coda when available; otherwise use values Sasha supplied at launch.
4. `assign(a11y_pr_reviewer)` for each PR with repo config context injected, including:
   - Paths to `docs/pr-scoring-rubric.md` and `templates/pr-comments/` in the a11y-ops-kit clone (same pattern as the live profile: e.g. `~/work/a11y-ops-kit/...`).
5. End turn. Do not run shell commands to wait. Inbox delivery is idle-based.
6. On reviewer results (respect **batch circuit breaker** before issuing new assigns):
  - If `verdict: WAIT` because CI is still pending, requeue the reviewer after the poll interval from repo config (default 3 minutes).
  - If `ci_failure_owner: ada` / `verdict: CI_BLOCKED`, route to the return-to-Ada list (reviewer already sent structured CI-blocked narrative to supervisor; optional operator paste to GitHub from `templates/pr-comments/ci-blocked.md`).
  - If `ci_failure_owner: ads`, `assign(a11y_developer)` with failing test details, worktree path, and optional `install_command` / `test_command_hint` from repo config when present.
  - If `ci_failure_owner: unknown`, route to human triage.
  - If `verdict: PASS` (after green CI and scoring), route to merge-ready list.
  - If `verdict: FLAG`, route to human review list.
  - If `verdict: FAIL`, route to return-to-Ada list.
7. On developer `READY_FOR_REVIEW`, reassign a reviewer for the current head SHA.
8. On developer `NEEDS_HUMAN`, route to human escalation.
9. Only a fresh reviewer result on the current head SHA can route a PR to merge-ready, human review, or return-to-Ada.
10. Compute **batch-level file overlap** from reviewer-reported `Changed files` lists (overlap does not appear in per-PR reviewer payloads).
11. **Calibration check.** Scan each worker’s output for noise or miscalibration (fields referencing files not in the PR, scores contradicting notes, heuristics misfiring). If issues found, append an entry to `docs/scoring-calibration-log.md` using that file’s template format, including batch ID and suggested prompt fix.
12. Produce batch summary using `templates/pr-comments/batch-summary.md` plus a **Coda update payload** (see [Coda live state](#coda-live-state)).
13. Clean up worker tmux sessions via `cao shutdown --session {session_name}` for each finished worker.
14. Present action list to Sasha (include “batch halted for triage” when the circuit breaker fired).

Profiles are self-contained in `skills/`; separate `cao-supervisor-protocols` / `cao-worker-protocols` skill packages are optional future wrappers, not required for v1.

Constraints:

- Never writes code or reviews diffs directly.
- Never merges.
- Never overrides a `CI_BLOCKED` result.
- May use bash only for CAO session orchestration, tmux lifecycle commands, and Coda sync helpers.
- Must end turn after dispatching all `assign` calls (idle-based message delivery).
- Include "check for stale worktrees at `/tmp/a11y-fix-*` and remove before creating new ones" in every developer assign message.
- After all workers report back, close their tmux sessions. Do not close own session.
- Must send a PR back to reviewer after `WAIT` or `READY_FOR_REVIEW`; developer output alone never completes review.
- If a worker has not responded after 10 minutes, log as blocker and close its session.

### Reviewer — file [`skills/cao-workback-reviewer.md`](../skills/cao-workback-reviewer.md), CAO `name: a11y_pr_reviewer`

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
- Paths to scoring rubric and comment templates (for composing structured text in the message body)

**GitHub comments (v1):** The reviewer does **not** post to the PR on GitHub. All results—including full score-card text and CI-blocked narrative—go to the supervisor via `send_message`. Templates under `templates/pr-comments/` (`score-card.md`, `ci-blocked.md`) are **reference layouts** for the structured message body, for batch summaries, optional manual paste by Sasha, or future automation.

Workflow:

1. Run `gh pr checks {number} --repo {repo}` for the current head SHA.
2. If checks pending: `send_message` with `verdict: WAIT`, `ci_state: pending`. Done.
3. If any CI job failed: diagnose why.
  - Use `gh pr view {number} --repo {repo} --json statusCheckRollup` and `gh run view {run_id} --repo {repo} --log-failed` as needed.
  - Classify `ci_failure_owner`:
    - `ada`: the code change itself is broken.
    - `ads`: existing tests assert on old DOM/strings that the a11y fix correctly changed.
    - `unknown`: cannot determine ownership.
  - If `ada`: `send_message` with `verdict: CI_BLOCKED`, `ci_failure_owner: ada`, and notes (body may follow `ci-blocked.md` structure). Done.
  - If `ads`: `send_message` with `verdict: WAIT`, `ci_failure_owner: ads`, failing test details, and re-review notes. Do NOT score. Done.
  - If `unknown`: `send_message` with `verdict: WAIT`, `ci_failure_owner: unknown`, and escalation notes. Do NOT score. Done.
4. If CI green: run pre-scoring heuristics, then score using the rubric path supplied in the assign message.
5. `send_message` structured result to supervisor (body may follow `score-card.md` layout). Do not post to GitHub.

Pre-scoring heuristics (mandatory before scoring):

1. **Test adjacency check**: For every changed component file, `rg` the directory tree for test files referencing changed elements (heading levels, aria attributes, string literals). If related tests exist and were not updated, feed into Test Completeness score.
2. **String drift detection**: When diff contains changed string literals, search test files for the old string value. If found, classify as `ci_failure_owner: ads`.
3. **CSS selector consistency**: When semantic HTML changes, search `.scss`/`.css`/`.module.`* for selectors targeting the old element.
4. **WCAG criterion cross-reference**: Verify change type matches stated criterion. The table below is a **minimum set**; the canonical list and edge cases live in `docs/pr-scoring-rubric.md` (Fix-Issue Alignment / examples).
  - `1.1.1` → alt text, image labeling
  - `1.3.1` → semantic HTML, headings, landmarks
  - `1.4.3` / `1.4.11` → color/contrast CSS
  - `2.4.2` → page title
  - `2.4.7` → focus styles and outlines
  - `3.3.1` → error association (aria-describedby)
  - `4.1.2` → ARIA attributes, roles, labels
5. **Dependency bump detection**: If `package.json` in changed files, flag as elevated Side Effect Risk.

Result format (per PR; **file overlap is batch-level only**—supervisor computes overlap after aggregating all PRs):

```
PR #1234
CI Merge Gate: PASS | CI_BLOCKED | WAIT
CI Failure Owner: ada | ads | unknown | n/a
Score: 5/16 | n/a
  Diff Scope: 1/3
  Fix-Issue Alignment: 0/3
  Test Completeness: 2/3
  Side Effect Risk: 1/3
  Convention Compliance: 1/2
  Historical Signal: 0/2
Tier: YELLOW | n/a
Verdict: PASS | FLAG | FAIL | WAIT | CI_BLOCKED
Next action: merge-ready | return-to-Ada | assign-developer | requeue-review | human-triage
Top risk dimension: Test Completeness
Affected routes: /pathway-admin, /pathway-admin/list
Changed files: PathwayCard.tsx, PathwayAdminList.tsx, PathwayCard.module.scss
Notes: Related test file exists in same directory and was not updated.
```

### Developer — file [`skills/cao-workback-developer.md`](../skills/cao-workback-developer.md), CAO `name: a11y_developer`

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
- Optional from repo config (injected by supervisor): `install_command`, `test_command_hint`, `package_manager`

Workflow:

1. Check for stale worktrees: `git worktree list | grep /tmp/a11y-fix-` and remove any that match the target path.
2. Create git worktree from the repo clone: `git worktree add {worktree_path} {branch_name}` (run from the main clone that already has `origin` set).
3. Work entirely inside the worktree directory.
4. **Install dependencies** before running tests:
   - If the assign message includes `install_command`, run that command from the worktree root.
   - Else follow the consumer repo’s documented install path (`README`, `docs/source-of-truth.md` in a11y-ops-kit for links, or squad conventions). Do **not** assume `node_modules` exists in a fresh worktree.
5. Read failing test files and the component diff.
6. Identify mechanical fixes:
  - Heading level assertions (`level: 3` → `level: 2`)
  - String literal updates in test expectations
  - Mock component updates (mock renders old element type)
  - Test query selectors targeting old DOM structure
  - Snapshot updates for changed DOM
7. Apply fixes to test files only.
8. Run the specific test suite to verify (use `test_command_hint` when provided).
9. Commit: `test: update assertions for a11y {change_type} changes`.
10. Push to the Workback branch.
11. Clean up worktree: `git worktree remove {worktree_path}`.
12. `send_message` result to supervisor so the PR can be re-reviewed on the new head SHA.

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
- Never marks a PR merge-ready. Every developer-touched PR must be re-reviewed by a reviewer on the new head SHA.
- If the fix requires understanding business logic or test intent beyond mechanical replacement, return `NEEDS_HUMAN`.
- Never creates new test files. Only updates existing ones.
- Always cleans up worktree on success or failure.

### Merge Assistant — file [`skills/cao-merge-assistant.md`](../skills/cao-merge-assistant.md), CAO `name: a11y_merge_assistant`

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
- Repo name (full `owner/repo` slug for `gh`)
- Merge method: squash-merge
- Default branch name if not `main` (from repo config `default_branch` or consumer repo convention)

**Preconditions (branch protection):** The merge assistant only runs `gh pr merge`. It does **not** approve reviews, bypass policies, or pass `--admin`. Sasha must ensure GitHub’s required reviews and required status checks are satisfied **before** merge (e.g., via normal review workflow or org policy). Common failure modes: merge rejected (missing approving review), branch not up to date, not mergeable, or checks not green—the assistant reports the `gh` error and stops.

Workflow:

1. For each PR in order:
  - Verify CI is still green via `gh pr checks {number} --repo {repo}`.
  - Check for merge conflicts with the current default branch (`main` unless repo config specifies otherwise).
  - If conflict: stop, report which PR conflicts and with what file.
  - Execute `gh pr merge {number} --repo {repo} --squash` (no `--admin` in v1).
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

Example (Account Hub): [`flows/a11y-monitor-account-hub.flow.md`](../flows/a11y-monitor-account-hub.flow.md). The script **must** receive the repo-short slug matching `repo-config/{repo-short}.md` (e.g. `account-hub`, `ariel`).

```yaml
---
name: a11y-monitor-account-hub
schedule: "0 */4 * * 1-5"
agent_profile: developer
provider: claude_code
script: ./scripts/check-recent-merges.sh account-hub
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

Canonical CAO profile bodies live under `skills/`; this spec duplicates YAML frontmatter for readability.

```
a11y-ops-kit/
  docs/
    pr-scoring-rubric.md              # canonical rubric (v0.1.0)
    source-of-truth.md
    em-questionnaire.md
    scoring-calibration-log.md
    specs/
      2026-04-13-a11y-review-team-design.md  # this spec
  skills/
    README.md                         # profile index (filename ↔ CAO name)
    cao-workback-supervisor.md
    cao-workback-reviewer.md
    cao-workback-developer.md
    cao-merge-assistant.md
  scheduled/
    README.md
    monitor-regression.md             # Claude Code cloud task spec
  flows/
    README.md
    a11y-monitor-account-hub.flow.md
    a11y-monitor-ariel.flow.md
  scripts/
    README.md
    check-recent-merges.sh            # monitor flow gate; arg = repo-config slug
  templates/
    pr-comments/
      ci-blocked.md
      score-card.md
      batch-summary.md
  repo-config/
    README.md
    account-hub.md
    ariel.md
  CHANGELOG.md
  README.md
```

## Config Resolution

Agent profiles are repo-agnostic. Static per-repo context comes from `repo-config/{repo}.md`. Live remediation state comes from Coda.

The supervisor reads the repo config file at batch start, reads trust phase and current batch state from Coda, then injects relevant sections into each worker's `assign` message. Workers never read config files directly.


| Agent           | Config injected by supervisor                                                                                              |
| --------------- | -------------------------------------------------------------------------------------------------------------------------- |
| Reviewer        | `ci_required_checks`, `branch_pattern`, `pr_author`, route map for changed files, known flaky tests, `ci_poll_interval_minutes`, trust phase from Coda |
| Developer       | Branch name, worktree path, repo clone location, test framework conventions, optional `install_command`, `test_command_hint`, `package_manager` |
| Merge Assistant | Merge method, required checks to verify pre-merge, full `owner/repo` slug, optional `default_branch`, trust phase from Coda if needed for routing logs |
| Monitor         | Reads config directly (CAO flow script reads `repo-config/`, cloud task clones repo)                                       |


Live fields such as `trust_phase`, `current_batch`, `Awaiting_Reaudit_Count`, and blocker status do not belong in `repo-config/`; they live in Coda.

Config file format (`repo-config/{repo}.md`):

Repo config files start with YAML **inside a fenced code block** at the top of the file, matching the pattern in [`repo-config/account-hub.md`](../repo-config/account-hub.md) (a `yaml`-labeled fence, the `---` delimited document, then a closing fence). That pattern lets [`scripts/check-recent-merges.sh`](../scripts/check-recent-merges.sh) parse fields with `sed`. The `repo` value must be the exact GitHub `owner/repo` slug used with `gh --repo`.

Illustrative frontmatter (YAML document only; in real files this is wrapped by the outer fenced block as in `account-hub.md`):

```yaml
---
repo: Multiverse-io/account_hub
domain: app.multiverse.io
squad: Trusted Enterprise Platform
em: TBD
squad_contact: TBD
slack_channel: "#a11y-ops-account-hub"
ci_required_checks:
  - test-and-deploy-workflow
branch_pattern: "workbackai/fix/*"
pr_author: ada-workbackai
default_branch: main
ci_poll_interval_minutes: 3
package_manager: yarn
install_command: yarn install --immutable
test_command_hint: yarn test PathwayAdminList.test.tsx
datadog:
  dashboard: https://app.datadoghq.eu/dashboard/cex-s7u-nk6/...
  service: account-hub
  baseline_cls: 0.1
  baseline_js_error_rate: 0.5
---
```

After that fence, the markdown **body** contains: route map, known hotspot files, known flaky tests, and notes.

Optional frontmatter keys (defaults if omitted):

| Key | Purpose |
| --- | --- |
| `default_branch` | Base branch for merge-conflict checks (`main` if omitted). |
| `ci_poll_interval_minutes` | Minutes before supervisor requeues a reviewer on pending CI (`3` if omitted). |
| `package_manager` | Hint only (`yarn`, `npm`, `pnpm`); used in runbooks until `install_command` is set. |
| `install_command` | Single shell command run from worktree root before tests (developer agent). |
| `test_command_hint` | Example test invocation for the developer agent. |

Config updates: edit file, commit, push. Next supervisor launch picks up changes.

Adding a new repo: copy existing config, fill from EM questionnaire, commit, and add the corresponding Repo Ops row in Coda.

## Coda live state

Coda holds **live** remediation state across batches (trust phase, active batch IDs, blockers, links). v1 does **not** require a Coda API integration: the supervisor treats Coda as the system of record but may **read** trust/batch from Coda when available and **write** via a copy-paste-friendly payload appended to the batch summary.

### Artifact model (contract v1)

Two logical tables (exact Coda table names may differ; columns should map 1:1):

**RepoOps** (one row per onboarded consumer repo)

| Column | Type | Description |
| --- | --- | --- |
| `repo_key` | text | Slug matching `repo-config` file stem (e.g. `account-hub`). |
| `github_repo` | text | Full `owner/repo` from config frontmatter. |
| `trust_phase` | text | e.g. `Batch 1`, `Batch 2-3`, `Mature`. |
| `current_batch_id` | text | Active or last-completed batch ID (e.g. `ah-3`). |
| `last_batch_summary_url` | url | Link to GitHub comment, doc, or Slack canvas. |
| `blockers` | text | Freeform blocker notes for the squad. |

**BatchRuns** (one row per supervisor execution)

| Column | Type | Description |
| --- | --- | --- |
| `batch_id` | text | Sasha-supplied batch ID. |
| `repo_key` | text | Same as RepoOps. |
| `started_at` | datetime | UTC. |
| `ended_at` | datetime | UTC. |
| `supervisor_profile_version` | text | e.g. `a11y_review_supervisor 0.1.1`. |
| `reviewer_profile_version` | text | Optional; echo from batch summary. |
| `developer_profile_version` | text | Optional. |
| `outcome` | text | `completed`, `halted_triage`, or `partial`. |
| `payload_markdown` | long text | Coda update payload below + link to full batch summary. |

### Coda update payload (supervisor output)

The supervisor includes a **Coda update payload** block at the end of the batch summary (markdown or JSON). Until automation exists, Sasha copies this block into the `BatchRuns.payload_markdown` cell (and updates RepoOps columns as needed).

Example payload:

```json
{
  "repo_key": "account-hub",
  "github_repo": "Multiverse-io/account_hub",
  "batch_id": "ah-1",
  "started_at": "2026-04-15T10:00:00Z",
  "ended_at": "2026-04-15T10:24:00Z",
  "supervisor_profile_version": "a11y_review_supervisor 0.1.1",
  "outcome": "completed",
  "trust_phase": "Batch 1",
  "merge_ready_prs": [823, 825],
  "human_review_prs": [],
  "return_to_ada_prs": [826],
  "blockers": "None"
}
```

Read path: at batch launch, the supervisor reads RepoOps / current Coda doc state **when available**; if Coda is unreachable or not yet wired, Sasha’s verbally supplied trust phase and batch metadata are authoritative for that run.

## Batch Naming Convention

Lightweight incrementing IDs: `{repo-short}-{sequence}`. Examples: `ah-1`, `ah-2`, `ariel-1`.

Sasha assigns the batch ID when launching the supervisor. The ID appears in all batch summaries, merge logs, Coda entries, and Slack posts.

## Regression Detection Patterns

### Pre-merge (Reviewer)

1. **Test adjacency check** — For every changed component file, search the directory tree for test files referencing changed elements. Highest-value heuristic: would have caught 17/19 Account Hub PRs and Ariel PR #3236.
2. **String drift detection** — When diff contains changed string literals, search test files for old value. If found, classify `ci_failure_owner: ads`.
3. **CSS selector consistency** — When semantic HTML changes, search stylesheets for selectors targeting the old element.
4. **WCAG criterion cross-reference** — Verify change type matches stated criterion family (minimum mapping in reviewer section; full examples in `docs/pr-scoring-rubric.md`).
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

Current trust phase is read from Coda at batch launch time. `Auto-merge` below means eligible for the prepared merge set without extra human diff review; Sasha still launches the merge assistant unless a later automation step removes that manual launch.


| Phase     | Auto-merge           | Agent review sufficient | Human required | Advance when                           |
| --------- | -------------------- | ------------------------- | -------------- | -------------------------------------- |
| Batch 1   | None                 | None                      | All            | n/a                                    |
| Batch 2-3 | None                 | GREEN (0-3)             | YELLOW+ (4+)   | Batch 1: 0 regressions                 |
| Batch 4+  | GREEN (0-3)          | YELLOW (4-7)            | ORANGE+ (8+)   | Batches 2-3: under 5% false PASS rate  |
| Mature    | GREEN + YELLOW (0-7) | ORANGE (8-11)           | RED (12-16)    | 100+ PRs with under 2% false PASS rate |

**Agent review sufficient** means no extra human diff review is required for that score tier under the current phase; it does not mean only agents may touch the repo or GitHub.

## CAO Compliance Notes

These are verified against the CAO documentation at `github.com/awslabs/cli-agent-orchestrator`:

1. **Required frontmatter fields**: `name`, `description`. All profiles include both.
2. **MCP server config**: All 4 CAO profiles include the `mcpServers` block with `type: stdio`, `command: uvx`, `args` pointing to `cao-mcp-server`.
3. **Role and tool restrictions**:
  - Supervisor: `role: supervisor` + `provider: claude_code` + `allowedTools: ["fs_read", "fs_list", "execute_bash", "@cao-mcp-server"]`. Bash is reserved for CAO/tmux lifecycle and Coda sync helpers, not direct diff review.
  - Reviewer: `role: reviewer` + `allowedTools: ["fs_read", "fs_list", "execute_bash", "@cao-mcp-server"]`. `allowedTools` overrides `role`. Codex uses soft enforcement.
  - Developer: `role: developer` (full access). Codex uses soft enforcement.
  - Merge Assistant: `role: developer` (full access). Claude Code uses hard enforcement.
4. **Provider values**: `claude_code` and `codex` are valid CAO provider values. Model variants (Opus, Sonnet, Spark) configured via provider CLI settings, not the `provider` frontmatter field.
5. **Idle-based message delivery**: Supervisor prompt explicitly instructs to end turn after dispatching `assign` calls. No busy-waiting.
6. **Assign vs handoff**: All worker dispatch uses `assign` (parallel, non-blocking). Workers return results via `send_message`. No `handoff` used in the default workflow.
7. **Skill loading**: v1 profiles in `skills/` are self-contained. Optional wrapper skills (e.g. shared CAO protocol snippets) may be added later; they are not required for assign/send_message flows.
8. **Tmux cleanup**: Supervisor closes worker sessions via `cao shutdown --session` after collecting results.
9. **Flow format**: Monitor flows use required fields (`name`, `schedule`, `agent_profile`) plus optional `provider` and `script`. Template variables use `[[var]]` syntax.

## Versioning

Each agent profile carries a version in its header. Versions follow semver:


| Change type                                             | Bump                  |
| ------------------------------------------------------- | --------------------- |
| Prompt wording tweak                                    | Patch (0.1.0 → 0.1.1) |
| New heuristic, new output field, workflow step change   | Minor (0.1.0 → 0.2.0) |
| Role restructure, scoring model change, new agent added | Major (0.1.0 → 1.0.0) |


All changes recorded in `CHANGELOG.md`. Supervisor includes agent versions in batch summaries.

## Rollout Plan

This rollout is the implementation path for the target architecture above. Active rollout still begins with Account Hub, then Ariel; additional repos require explicit onboarding before they enter the live queue.

### Phase 0 — Dry run

- Validate existing CAO profiles under `skills/` against this spec (frontmatter, assign/send_message, idle turn-taking).
- Run supervisor + 1 reviewer against Account Hub PR #823 (simplest: pure `aria-label` addition, CI green).
- Compare agent output against Sasha's manual review.
- Goal: validate profile format, assign/send_message flow, structured score payload (no GitHub comment required in v1).

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


| Transition           | Requirement                                                       |
| -------------------- | ----------------------------------------------------------------- |
| Phase 0 → 1          | Dry run completes, score card is reasonable                       |
| Phase 1 → 2          | 0 regressions, agent scores within 2 points of manual on 80%+ PRs |
| Phase 2 → 3          | Account Hub running smoothly, no stop-the-line incidents          |
| Per-repo Batch 1 → 2 | 0 regressions, 0% false PASS rate                                 |
| Batch 2-3 → 4+       | Under 5% false PASS rate                                          |


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