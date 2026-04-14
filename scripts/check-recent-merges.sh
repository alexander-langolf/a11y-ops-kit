#!/usr/bin/env bash
#
# Conditional execution script for CAO monitor flows.
# Returns JSON for CAO flow template variable substitution.
#
# Usage: ./check-recent-merges.sh <repo-short>
#   repo-short: account-hub, ariel, etc.
#
# Output (stdout, JSON):
#   {"execute": false, "output": {}}                    — no recent merges, skip
#   {"execute": true,  "output": {repo, merge_summary,  — recent merges found
#     datadog_url, baseline_cls, baseline_js_error_rate,
#     slack_channel}}

set -euo pipefail

REPO_SHORT="${1:?Usage: check-recent-merges.sh <repo-short>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../repo-config/${REPO_SHORT}.md"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config not found at ${CONFIG_FILE}" >&2
  exit 1
fi

# Extract frontmatter values from the repo config.
# Config files use ```yaml fenced blocks for frontmatter.
extract_field() {
  local field="$1"
  sed -n '/^```yaml/,/^```/p' "$CONFIG_FILE" | grep "^${field}:" | head -1 | sed "s/^${field}: *//" | tr -d '"'
}

extract_nested_field() {
  local parent="$1" field="$2"
  sed -n '/^```yaml/,/^```/p' "$CONFIG_FILE" \
    | sed -n "/^${parent}:/,/^[^ ]/p" \
    | grep "^  ${field}:" | head -1 | sed "s/^  ${field}: *//" | tr -d '"'
}

REPO=$(extract_field "repo")
SLACK_CHANNEL=$(extract_field "slack_channel")
BRANCH_PATTERN=$(extract_field "branch_pattern")
PR_AUTHOR=$(extract_field "pr_author")
DATADOG_URL=$(extract_nested_field "datadog" "dashboard")
BASELINE_CLS=$(extract_nested_field "datadog" "baseline_cls")
BASELINE_JS_ERROR_RATE=$(extract_nested_field "datadog" "baseline_js_error_rate")

if [[ -z "$REPO" ]]; then
  echo "Error: could not extract repo from ${CONFIG_FILE}" >&2
  exit 1
fi

# Check for Workback merges in the last 6 hours.
SINCE=$(date -u -v-6H '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -d '6 hours ago' '+%Y-%m-%dT%H:%M:%SZ')

MERGES=$(gh pr list \
  --repo "$REPO" \
  --state merged \
  --author "$PR_AUTHOR" \
  --json number,title,mergedAt,headRefName \
  --jq "[.[] | select(.mergedAt >= \"${SINCE}\" and (.headRefName | test(\"workbackai/fix/\")))]" \
  2>/dev/null || echo "[]")

COUNT=$(echo "$MERGES" | jq 'length')

if [[ "$COUNT" -eq 0 ]]; then
  echo '{"execute": false, "output": {}}'
  exit 0
fi

MERGE_SUMMARY=$(echo "$MERGES" | jq -r '.[] | "#\(.number) \(.title) — merged \(.mergedAt)"' | paste -sd '\n' -)

jq -n \
  --arg repo "$REPO" \
  --arg merge_summary "$MERGE_SUMMARY" \
  --arg datadog_url "$DATADOG_URL" \
  --arg baseline_cls "$BASELINE_CLS" \
  --arg baseline_js_error_rate "$BASELINE_JS_ERROR_RATE" \
  --arg slack_channel "$SLACK_CHANNEL" \
  '{
    execute: true,
    output: {
      repo: $repo,
      merge_summary: $merge_summary,
      datadog_url: $datadog_url,
      baseline_cls: $baseline_cls,
      baseline_js_error_rate: $baseline_js_error_rate,
      slack_channel: $slack_channel
    }
  }'
