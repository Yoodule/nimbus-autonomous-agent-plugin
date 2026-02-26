# Nimbus Plugin - Complete Setup Guide

**Status**: ✅ Production Ready (February 26, 2026)

## What is Nimbus?

Nimbus is a **Claude Code plugin** that provides an industry-standard job queue system for autonomous task management with full dependency resolution.

## Structure

This is a proper Claude Code plugin following the official structure:

```
.claude/plugins/nimbus/
├── .claude-plugin/
│   └── plugin.json                    # Plugin metadata
├── skills/
│   ├── nimbus/SKILL.md               # Add tasks
│   ├── nimbus-query/SKILL.md         # Query status (agents)
│   ├── nimbus-status/SKILL.md        # View queue
│   └── nimbus-stop/SKILL.md          # Remove tasks
├── bin/
│   ├── nimbus-start                  # Task executor
│   ├── nimbus-query                  # Status query
│   ├── nimbus-status                 # Queue viewer
│   ├── nimbus-stop                   # Task remover
│   └── nimbus-verify                 # System checker
├── hooks/
│   └── on_nimbus.sh                  # Stop hook (processes queue)
├── lib/
│   └── queue-utils.sh                # Shared utilities
├── docs/
│   ├── QUEUE.md                      # Full documentation
│   ├── QUICK_START.md                # Quick reference
│   └── UPGRADE.md                    # Implementation details
├── queue.json                        # Task queue (created at runtime)
└── README.md                         # Plugin overview
```

## Quick Start

### 1. Add a Task
```bash
/nimbus "Run tests" --completion-promise "Tests passing"
```

### 2. View Queue
```bash
/nimbus-status
```

### 3. Query Status (for agents)
```bash
/nimbus-query status 1
/nimbus-query status 1 --json
/nimbus-query deps-met 2
```

### 4. Chain Tasks
```bash
/nimbus "Tests" --task-id tests --completion-promise "Tests pass"
/nimbus "Build" --depends-on tests --completion-promise "Built"
/nimbus "Deploy" --depends-on build --completion-promise "Live"
```

## Plugin Files

### Configuration
- **`.claude-plugin/plugin.json`** - Plugin metadata (name, version, description)
- **`.claude/settings.json`** - Hook configuration (points to this plugin)

### Skills (Commands)
Each skill is a folder with `SKILL.md`:

- **`nimbus`** - `/nimbus` - Add tasks to queue
- **`nimbus-query`** - `/nimbus-query` - Query status (for agents/automation)
- **`nimbus-status`** - `/nimbus-status` - View all tasks
- **`nimbus-stop`** - `/nimbus-stop` - Remove tasks

### Executable Scripts
- **`bin/nimbus-start`** - Adds task to queue (called by /nimbus skill)
- **`bin/nimbus-query`** - Queries task status
- **`bin/nimbus-status`** - Shows queue status
- **`bin/nimbus-stop`** - Removes task
- **`bin/nimbus-verify`** - Verifies system setup

### Support
- **`hooks/on_nimbus.sh`** - Stop hook that processes queue
- **`lib/queue-utils.sh`** - Shared queue utilities
- **`queue.json`** - Task queue data (auto-created)

### Documentation
- **`README.md`** - Plugin overview
- **`docs/QUEUE.md`** - Complete reference
- **`docs/QUICK_START.md`** - Quick start guide
- **`docs/UPGRADE.md`** - Implementation details

## How It Works

### Architecture: Queue-Based Worker

```
Producer (you) → Task Queue (queue.json) → Worker Hook → Process
```

1. **You add tasks**: `/nimbus "task" --completion-promise "done"`
2. **Tasks queue**: Stored in `.claude/plugins/nimbus/queue.json`
3. **Hook processes**: Stop hook activates next eligible task
4. **Dependencies resolved**: Waits for dependencies to complete
5. **Loop continues**: Repeats until queue is empty

### Task Lifecycle

```
queued (waiting for deps?)
  ↓
active (being processed)
  ↓
completed (output <promise>...</promise>)
```

### Hook Integration

The stop hook is configured in `.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/plugins/nimbus/hooks/on_nimbus.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

On session stop:
1. Hook reads `.claude/plugins/nimbus/queue.json`
2. Checks if active task is complete
3. Finds next queued task with dependencies met
4. Feeds prompt back to Claude
5. Session continues (doesn't exit)

## Features

✅ **Multi-Task Queue** - Queue multiple tasks independently
✅ **Dependency Resolution** - Tasks wait for dependencies
✅ **Task Chains** - Create pipelines: tests → build → deploy
✅ **Agent-Friendly** - Programmatic status queries with JSON output
✅ **Persistent State** - Queue persists across sessions
✅ **Industry Standard** - Job queue pattern (like Celery, Bull, RQ)
✅ **Self-Contained** - Full plugin with skills, hooks, utilities

## Verification

Check that everything is set up correctly:

```bash
./.claude/plugins/nimbus/bin/nimbus-verify
```

Should output:
```
🎉 All checks passed! Nimbus is ready to use.
```

## Examples

### CI/CD Pipeline
```bash
/nimbus "Run tests" --task-id tests --completion-promise "All tests passing"
/nimbus "Build image" --depends-on tests --completion-promise "Image built"
/nimbus "Deploy staging" --depends-on build --completion-promise "Staging live"
/nimbus "Run smoke tests" --depends-on staging --completion-promise "Smoke tests pass"
```

### Parallel Work Then Join
```bash
/nimbus "API tests" --task-id api --completion-promise "API tests pass"
/nimbus "UI tests" --task-id ui --completion-promise "UI tests pass"
/nimbus "Deploy" --depends-on "api,ui" --completion-promise "Deployed"
```

### Agent Automation
```bash
# Check if task 1 completed
STATUS=$(/nimbus-query status 1 --json | jq -r '.status')
[[ "$STATUS" == "completed" ]] && echo "Done!"

# Only start if dependencies met
/nimbus-query deps-met 2 && echo "Task 2 can start"

# Find what we're waiting for
UNMET=$(/nimbus-query unmet-deps 2)
[[ -n "$UNMET" ]] && echo "Waiting for: $UNMET"
```

## Documentation

- **Quick Start**: See `docs/QUICK_START.md` for 30-second overview
- **Full Guide**: See `docs/QUEUE.md` for complete reference
- **Implementation**: See `docs/UPGRADE.md` for architecture details

## Commands Summary

| Command | Purpose |
|---------|---------|
| `/nimbus TASK` | Add task to queue |
| `/nimbus-status` | View all tasks |
| `/nimbus-stop ID` | Remove task |
| `/nimbus-query status ID` | Get task status |
| `/nimbus-query status ID --json` | Get JSON status |
| `/nimbus-query deps-met ID` | Check if ready |
| `/nimbus-query unmet-deps ID` | Find what's waiting |
| `nimbus-verify` | Verify setup |

## Requirements

- Bash 3.2+ (macOS/Linux standard)
- `jq` (JSON processor)
- `.claude/settings.json` with hook configured

All included and verified by `nimbus-verify`.

## Architecture Pattern

**Job Queue Pattern** (Industry Standard)

Used by:
- ✅ **Celery** (Python)
- ✅ **Bull** (Node.js)
- ✅ **RQ** (Redis Queue)
- ✅ **Sidekiq** (Ruby)
- ✅ **Apache Airflow** (Workflow orchestration)

Benefits:
- Separates task production from consumption
- Enables sequential processing with parallel queuing
- Scales from single worker to multiple workers
- Clean, well-understood pattern

## Future Enhancements

Ready for:
- Multi-worker support (spawn multiple Claude sessions)
- Task retries on failure
- Priority queues
- Task timeout/auto-fail
- Dead letter queues
- Task webhooks
- Custom metadata

## Status

✅ **Production Ready**
- All tests passing
- All paths verified
- Hook configured and working
- Plugin structure correct
- Full documentation included

**Last verified**: 2026-02-26 07:51 UTC

---

**Plugin Pattern**: Claude Code Standard
**Created**: 2026-02-26
**Version**: 1.0.0
