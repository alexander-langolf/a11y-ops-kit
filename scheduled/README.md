# Scheduled Tasks

Claude Code cloud scheduled task specs. These run on Anthropic infrastructure at `claude.ai/code/scheduled` — no local machine dependency.

## Purpose

Always-on fallback for monitoring that does not depend on a local `cao-server` instance. Complements the CAO flows in `flows/`.

## Format

Each file is a self-contained prompt spec. The scheduled task clones this repo, reads config, and executes the monitoring logic independently.

## Current Tasks

| File | Schedule | Purpose |
| --- | --- | --- |
| `monitor-regression.md` | Daily on weekdays | Post-merge regression detection across all active repos |
