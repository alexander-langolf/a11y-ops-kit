# Rollback Protocol

Version: `0.1.0`

Audience: ADS operators, the regression Monitor agent, on-call

Purpose: define the safe path from "regression suspected" to "production stable" after a Workback a11y batch merge. The Monitor only recommends reverts. An operator executes them.

## When To Revert vs Forward-Fix

Revert when any of the following holds:

- Monitor confidence is `high` and the suspect PR has Side Effect Risk 2+.
- A user-facing route's CLS, JS error rate, or LCP crosses its configured threshold and correlates within 15 minutes of the merge.
- A hotfix would ship slower than a revert (e.g., squad contact is unavailable, Ada has no context on the affected file).

Forward-fix when all of the following hold:

- The change is strictly additive (pure aria attribute, role, tabindex) with no CSS or DOM restructure.
- The fix is a single-line diff a human can verify in under 5 minutes.
- CI can run and confirm the fix before the next synthetic monitoring run.

When in doubt, revert. A clean revert is cheaper than a rushed forward-fix.

## Revert Order

The default order is **reverse merge order**. If PRs merged in order `#a, #b, #c` and regression onset correlates with `#b`, revert `#c` first, then `#b`. This avoids re-applying the broken state of `#b` under a layer of `#c`.

Exception: if `#c` is strictly additive and does not touch files overlapping with `#b`, revert only `#b`.

## File Overlap Check

Before executing the first revert, consult the batch summary's `## File Overlap Warnings` block. If the suspect PR shares changed files with any already-merged PR from the same batch, treat those PRs as a **revert group** and revert them together in reverse order. Reverting one PR out of an overlap cluster will conflict.

If no batch summary is available, run:

```bash
gh pr diff {suspect_pr} --repo {repo} --name-only > /tmp/files.txt
for pr in {batch_pr_list}; do
  gh pr diff "$pr" --repo {repo} --name-only \
    | grep -F -f /tmp/files.txt \
    | head -1 \
    && echo "#$pr overlaps"
done
```

Any PR reported as "overlaps" joins the revert group.

## Stop-The-Line

Stop on the first conflict encountered during revert. Do not attempt conflict resolution automatically — the state is already degraded and a bad resolution compounds the problem.

Conflict protocol:

1. Emit `REVERT HALTED — PR #{n} conflicts with {file}` to the repo's Slack channel.
2. Leave any successful reverts in place.
3. Hand off to the EM or a squad contact with the conflict details and the list of remaining PRs to revert.

## Commands

```bash
# Create a revert PR for a single merged PR.
gh pr revert {pr_number} --repo {repo}

# Merge the revert PR once CI is green. Squash to keep history linear.
gh pr merge {revert_pr} --repo {repo} --squash
```

Do not use `git revert` locally and push to main directly — every revert goes through the normal PR + CI path.

## Post-Revert Coda Updates

For each reverted PR, update its Issue row in Coda:

- `Status` → `Reverted`
- `Notes` → one-line cause and link to the Monitor report that triggered the revert
- `Followup_PR_URL` → the revert PR URL

If the revert was escalated to a human because of a conflict, also add a row in the Blockers log with:

- `Type` → `revert-conflict`
- `Severity` → `high`
- `Summary` → the conflicting files and the halted PR number
- `Owner` → the person taking the conflict

## Linking From Monitors

The `flows/a11y-monitor-*.flow.md` regression report tells the operator which PR to revert. That report should link to this doc in its recommendation line. The cloud `scheduled/monitor-regression.md` prompt does the same.
