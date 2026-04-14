# Repo Config

Static per-repo configuration for the a11y review team. Each file provides context that the supervisor injects into worker `assign` messages.

Live remediation state (trust phase, current batch, blocker status, Awaiting Re-audit count) does not belong here — it lives in Coda.

## Format

Each config file uses YAML frontmatter for structured fields and a markdown body for free-form context.

```yaml
---
repo: Multiverse-io/{repo-name}
domain: {production domain}
squad: {owning squad name}
em: {engineering manager — TBD until EM questionnaire completed}
squad_contact: {primary contact — TBD until confirmed}
slack_channel: "#a11y-ops-{repo-short}"
ci_required_checks:
  - {check-name}
branch_pattern: "workbackai/fix/*"
pr_author: ada-workbackai
datadog:
  dashboard: {dashboard URL}
  service: {service name}
  baseline_cls: {number}
  baseline_js_error_rate: {number}
---
```

Body contains:
- Route map (file → route mapping for affected route detection)
- Known hotspot files (high-overlap files across PRs)
- Known flaky tests (to exclude from CI failure triage)
- Notes (repo-specific quirks, conventions, or warnings)

## Adding a New Repo

1. Copy an existing config file.
2. Fill fields from the EM questionnaire (`docs/em-questionnaire.md`).
3. Populate route map from the repo's routing config.
4. Commit and push. Next supervisor launch picks up changes.
5. Add the corresponding Repo Ops row in Coda.

## Config Updates

Edit the file, commit, push. No cache invalidation needed — the supervisor reads from the file at batch start.
