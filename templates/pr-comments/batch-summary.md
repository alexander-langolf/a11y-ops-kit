## Batch `{batch_id}` Summary

Agent versions: supervisor `{supervisor_version}`, reviewer `{reviewer_version}`, developer `{developer_version}`

| Result | Count | PRs |
| --- | --- | --- |
| GREEN | `{green_count}` | `{green_prs}` |
| YELLOW | `{yellow_count}` | `{yellow_prs}` |
| ORANGE | `{orange_count}` | `{orange_prs}` |
| RED | `{red_count}` | `{red_prs}` |
| CI blocked | `{ci_blocked_count}` | `{ci_blocked_prs}` |

Developer dispatched: `{developer_count}` (`{developer_details}`)

Scored PR distribution: avg `{avg_score}`, median `{median_score}`, max `{max_score}`

### File Overlap Warnings

`{file_overlap_warnings}`

### Action Needed

- Review PRs: `{review_prs}`
- Return to Ada for CI recovery: `{ci_recovery_prs}`
- Human triage (unknown CI failure owner): `{human_triage_prs}`
- Human escalation (developer NEEDS_HUMAN): `{human_escalation_prs}`
- Merge-ready under current trust phase: `{merge_ready_prs}`
- Recommended merge order: `{merge_order}`
