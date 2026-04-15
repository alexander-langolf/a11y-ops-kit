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
datadog:
  dashboard: https://app.datadoghq.eu/dashboard/cex-s7u-nk6/...
  service: account-hub
  baseline_cls: 0.1
  baseline_js_error_rate: 0.5
---
```

## Route Map

| File pattern | Route(s) |
| --- | --- |
| `AccountSignUpForm.*` | /registration |
| `RegionSelect.*` | /registration, /region-select |
| `FormError.*` | /registration (shared component) |

TBD — populate from account-hub routing config after EM questionnaire.

## Known Hotspot Files

- `AccountSignUpForm.tsx` — touched by 4/19 Workback PRs, high merge conflict risk.

## Known Flaky Tests

TBD — populate after Batch 1 calibration.

## Notes

- 19 open Workback PRs, 0 merged as of initial analysis.
- 31.6% CI first-pass rate (6/19 green).
- 17/19 PRs touch zero test files — dominant failure mode.
- 18/19 PRs opened same day — batch-open pattern.
