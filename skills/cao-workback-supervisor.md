# CAO Workback Supervisor

Version: `0.1.0`

```yaml
---
name: a11y_review_supervisor
description: Coordinates batch review of Workback accessibility remediation PRs across Multiverse apps
role: supervisor
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

Bash access is reserved for CAO/tmux lifecycle commands and Coda sync helpers. The supervisor does not review diffs or write repo code.

## Inputs

Provided by Sasha at launch:

- Repo name and GitHub org
- Batch ID (e.g., `ah-1`, `ariel-1`)
- PR numbers in the batch
- Current trust phase
- WCAG criteria family
- Historical signal notes

## Required References

- [`../docs/pr-scoring-rubric.md`](../docs/pr-scoring-rubric.md)
- [`../docs/source-of-truth.md`](../docs/source-of-truth.md)
- [`../templates/pr-comments/batch-summary.md`](../templates/pr-comments/batch-summary.md)
- `repo-config/{repo}.md` for static CI checks, routes, contacts
- Coda for trust phase, current batch state, and blocker notes

## Workflow

1. Load `cao-supervisor-protocols` skill.
2. Get own `$CAO_TERMINAL_ID`.
3. Read static `repo-config/{repo}.md` from the a11y-ops-kit clone.
4. Read current trust phase, current batch, and relevant blocker notes from Coda.
5. `assign(a11y_pr_reviewer)` for each PR with repo config context injected.
6. End turn. Do not run shell commands to wait. Inbox delivery is idle-based.
7. On reviewer results, route by state:
   - `verdict: WAIT` + `ci_state: pending` → requeue reviewer after poll interval.
   - `ci_failure_owner: ada` → already commented, add to "return to Ada" list.
   - `ci_failure_owner: ads` → `assign(a11y_developer)` with failing test details and worktree path. Include "check for stale worktrees at `/tmp/a11y-fix-*` and remove before creating new ones" in the assign message.
   - `ci_failure_owner: unknown` → add to human triage list.
   - `developer_status: READY_FOR_REVIEW` → `assign(a11y_pr_reviewer)` again on current head SHA.
   - `developer_status: NEEDS_HUMAN` → add to human escalation list.
   - `verdict: PASS` → merge-ready list.
   - `verdict: FLAG` → human review list.
   - `verdict: FAIL` → return to Ada list.
8. Wait for developer or re-review results if dispatched.
9. If a worker has not responded after 10 minutes, log as blocker and close its session.
10. Compute file overlap from reviewer-reported changed file lists across all PRs in the batch.
11. Produce batch summary using `templates/pr-comments/batch-summary.md` plus a Coda update payload.
12. Clean up worker tmux sessions via `cao shutdown --session {session_name}` for each finished worker. Do not close own session.
13. Include agent versions in the batch summary.
14. Present action list to Sasha.

A PR only becomes merge-ready from a fresh reviewer result on the current head SHA. Developer output can request re-review, but it never makes a PR merge-ready by itself.

## Constraints

- Never writes code or reviews diffs directly.
- Never merges.
- Never overrides a `CI_BLOCKED` result.
- May use bash only for CAO session orchestration, tmux lifecycle commands, and Coda sync helpers.
- Must end turn after dispatching all `assign` calls (idle-based message delivery).
- Must send a PR back to reviewer after `WAIT` or `READY_FOR_REVIEW`; developer output alone never completes review.
- After all workers report back, close their tmux sessions. Do not close own session.

## Expected Output

```text
Batch ah-1 — Summary

Agent versions: supervisor 0.1.0, reviewer 0.1.0, developer 0.1.0

| Result      | Count | PRs                         |
| ----------- | ----- | --------------------------- |
| GREEN       | 4     | #815, #818, #820, #823      |
| YELLOW      | 1     | #825                        |
| ORANGE      | 0     |                             |
| RED         | 0     |                             |
| CI_BLOCKED  | 1     | #830                        |

Developer dispatched: 1 (PR #819 — ads-owned CI failure, test fix applied, re-reviewed)

File overlap warnings:
- AccountSignUpForm.tsx shared by PRs #815, #819, #825, #830 — merge conflict risk

Scored PR distribution: avg 2.4, median 2, max 5

Action needed:
- Merge-ready under current trust phase: #815, #818, #820, #823
- Review YELLOW PR: #825
- Return CI-blocked PR to Ada: #830
- Recommended merge order: #823, #820, #818, #815 (file overlap: merge #815 last)
```
