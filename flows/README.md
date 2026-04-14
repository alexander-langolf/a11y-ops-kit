# Flows

CAO flow definitions for scheduled agent tasks. Requires `cao-server` running on the operator's machine.

## Format

Each flow file uses YAML frontmatter with required fields:

```yaml
---
name: {flow-name}
schedule: "{cron expression}"
agent_profile: {CAO profile name}
provider: {claude_code | codex}
script: {path to conditional execution script}
---
```

The prompt body follows the frontmatter. Template variables use `[[var]]` syntax and are filled from the script's JSON output.

## Conditional Execution

The `script` field points to a shell script that runs before the agent launches. The script returns JSON:

- `{"execute": false, "output": {}}` — no work to do, skip the run.
- `{"execute": true, "output": {"repo": "...", "merge_summary": "...", ...}}` — populate `[[var]]` placeholders and launch the agent.

## Current Flows

| Flow | Schedule | Purpose |
| --- | --- | --- |
| `a11y-monitor-account-hub.flow.md` | Every 4h on weekdays | Post-merge regression detection for Account Hub |
| `a11y-monitor-ariel.flow.md` | Every 4h on weekdays | Post-merge regression detection for Ariel |

Additional repo flows are added as repos are onboarded.
