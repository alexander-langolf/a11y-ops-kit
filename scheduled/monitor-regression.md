# Monitor Regression — Cloud Scheduled Task

Schedule: daily on weekdays
Provider: Claude Code cloud task (`claude.ai/code/scheduled`)

Self-contained prompt — no local machine dependency.

## Prompt

You are monitoring Multiverse Stardust consumer repos for post-merge regressions from Workback accessibility remediation PRs.

### Setup

1. Clone the `a11y-ops-kit` repo.
2. Read every file in `repo-config/*.md` to get the list of active repos and their Datadog config.
3. For each repo, check `baselines_verified` in the config frontmatter. If not `true`, skip the repo and emit `MONITOR SKIPPED — {repo}: baselines not verified`. Only continue for repos where `baselines_verified: true`.
4. For each remaining repo, check for recent Workback merges (last 24h):
   - `gh pr list --repo {repo} --state merged --author ada-workbackai --json number,title,mergedAt,files`
   - Filter to branches matching `workbackai/fix/*`.
5. If no recent merges for a repo, skip it.

### For Each Repo With Recent Merges

1. Read the repo config for Datadog dashboard URL, service name, and baseline metrics.
2. Query Datadog RUM metrics for the last 24 hours:
   - CLS on affected routes (compare against `baseline_cls`).
   - JS error rate (compare against `baseline_js_error_rate`).
   - LCP on affected routes.
3. Correlate metric changes against per-PR merge timestamps.
   - A metric change within 15 minutes of a merge implicates that PR.
4. Match affected routes to PRs that modified components on those routes (use the route map from repo config).
5. Check for revert commits or hotfix PRs touching batch files within 48h of merge.

### Output

For each repo checked, produce one of:

**Regression detected:**

```text
REGRESSION DETECTED — {repo}
Metric: {metric} > {threshold} on {route}
Onset: {time} ({minutes} min after PR #{number} merged)
Suspect PR: #{number} (Side Effect Risk: {score}, {change description})
Evidence: {route match + timing + risk score}
Recommendation: revert PR #{number} per `docs/rollback-protocol.md` (reverse merge order, check file overlap first)
Confidence: high | medium | low
```

Post to the repo's `slack_channel` from its config with the relevant Coda link.

**All clear:**

```text
ALL CLEAR — {repo}
Checked: {timestamp}
Merges in last 24h: {count}
CLS: {value} (baseline: {baseline_cls})
JS error rate: {value} (baseline: {baseline_js_error_rate})
No regressions detected.
```

### Behavioral Checks

For any repo with merged PRs touching user-facing routes, generate a manual Heap check checklist:

```text
Manual Heap check recommended for {repo}:
- {route}: compare completion rate 24h before vs after merge
- {route}: check for rage clicks on {changed elements}
- {route}: check for drop-offs after {component} changes
```
