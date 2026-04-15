```yaml
---
repo: Multiverse-io/ariel
domain: TBD
squad: TBD
em: TBD
squad_contact: TBD
slack_channel: "#a11y-ops-ariel"
ci_required_checks:
  - js-tests
branch_pattern: "workbackai/fix/*"
pr_author: ada-workbackai
default_branch: main
ci_poll_interval_minutes: 3
datadog:
  dashboard: TBD
  service: ariel
  baseline_cls: TBD
  baseline_js_error_rate: TBD
---
```

## Route Map

| File pattern | Route(s) |
| --- | --- |
| `PathwayCard.*` | /pathway-admin, /pathway-admin/list |
| `PathwayAdminList.*` | /pathway-admin, /pathway-admin/list |

TBD — populate from ariel routing config after EM questionnaire.

## Known Hotspot Files

TBD — only 2 open Workback PRs, insufficient data.

## Known Flaky Tests

TBD — populate after Batch 1 calibration.

## Notes

- 2 open Workback PRs, 0 merged as of initial analysis.
- PR #3236: heading h3→h2, `js-tests` failing because `PathwayAdminList.test.tsx` still asserts `level: 3`. Ada updated `PathwayCard.test.tsx` but missed the parent component's test.
- PR #3238: pure `aria-label` addition, all CI green. Single file, zero test impact. Good dry-run candidate.
