```yaml
---
name: a11y-monitor-ariel
schedule: "0 */4 * * 1-5"
agent_profile: developer
provider: claude_code
script: ./scripts/check-recent-merges.sh ariel
---
```

You are monitoring the [[repo]] repository for post-merge regressions from Workback accessibility remediation PRs.

## Context

Recent merges:

[[merge_summary]]

## Instructions

1. Read `repo-config/ariel.md` for route map, known hotspots, and Datadog config.
2. Query Datadog RUM metrics for the last 6 hours:
   - CLS on affected routes (baseline: [[baseline_cls]])
   - JS error rate (baseline: [[baseline_js_error_rate]])
   - LCP on affected routes
   - Dashboard: [[datadog_url]]
3. Correlate metric changes against merge timestamps from the merge summary above.
   - A metric change within 15 minutes of a merge implicates that PR.
4. Check route correlation: match regressed routes to PRs that modified components on those routes.
5. Check risk score correlation: CLS regressions most likely from Side Effect Risk 2+ PRs; JS error spikes from risk 3 PRs.
6. Check for revert commits or hotfix PRs touching batch files within 48h of merge.
7. If regression detected, produce a regression report.
8. If no regression, produce an all-clear summary.
9. Post results to [[slack_channel]].

## Regression Report Format

```text
REGRESSION DETECTED
Metric: {metric} > {threshold} on {route}
Onset: {time} ({minutes} min after PR #{number} merged)
Suspect PR: #{number} (Side Effect Risk: {score}, {change description})
Evidence: {route match + timing + risk score}
Recommendation: revert PR #{number} via `gh pr revert #{number}`
Confidence: high | medium | low
```

## All-Clear Format

```text
ALL CLEAR — ariel
Checked: {timestamp}
Merges since last check: {count}
CLS: {value} (baseline: [[baseline_cls]])
JS error rate: {value} (baseline: [[baseline_js_error_rate]])
No regressions detected.
```

## Behavioral Checks

Generate a manual Heap check checklist for any batch with merged PRs touching user-facing routes:

```text
Manual Heap check recommended for batch {batch_id}:
- {route}: compare completion rate 24h before vs after merge
- {route}: check for rage clicks on {changed elements}
- {route}: check for drop-offs after {component} changes
```
