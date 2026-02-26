# Nimbus: Multi-Task Autonomous Agent System

Industry-standard job queue for autonomous task management with dependency resolution.

## Folder Structure

```
nimbus/
├── README.md              # This file
├── queue.json             # Central task queue (auto-created)
├── lib/
│   └── queue-utils.sh     # Queue management utilities
├── bin/
│   ├── nimbus-start       # Add tasks to queue
│   ├── nimbus-status      # View queue status
│   ├── nimbus-stop        # Remove/cancel tasks
│   ├── nimbus-query       # Query task status (for agents)
│   └── nimbus-verify      # Verify system setup
├── hooks/
│   └── on_nimbus.sh       # Stop hook - processes queue
└── docs/
    ├── QUEUE.md           # Complete documentation
    ├── QUICK_START.md     # Quick reference
    └── UPGRADE.md         # Implementation details
```

## Quick Start

### Add a Task
```bash
/nimbus "Your task" --completion-promise "When complete"
```

### With Dependencies
```bash
/nimbus "Step 2" --depends-on 1 --completion-promise "Complete"
```

### View Queue
```bash
/nimbus-status
```

### Query Status (for agents)
```bash
/nimbus-query status 1
/nimbus-query status 1 --json
/nimbus-query deps-met 2
```

## How It Works

**Producer → Queue → Worker Hook → Process**

1. You add tasks with `/nimbus` - they queue in `queue.json`
2. The stop hook (enabled in `.claude/settings.json`) processes one task at a time
3. When a task completes, the hook finds the next eligible queued task
4. Tasks with dependencies wait until their dependencies complete
5. Loop continues until queue is empty

## Files Reference

| File | Purpose |
|------|---------|
| `queue.json` | Central task queue (auto-created on first use) |
| `lib/queue-utils.sh` | Shared utilities for queue operations |
| `bin/nimbus-*` | CLI commands for task management |
| `hooks/on_nimbus.sh` | Stop hook that processes queue |
| `docs/` | Complete documentation |

## Commands

### Management
- `nimbus-start` - Add task to queue (via `/nimbus` skill)
- `nimbus-status` - View all tasks and progress
- `nimbus-stop` - Remove task from queue
- `nimbus-verify` - Check system setup

### Querying (for agents)
- `nimbus-query status <id>` - Get task status
- `nimbus-query status <id> --json` - JSON for scripts
- `nimbus-query deps-met <id>` - Check if ready to start
- `nimbus-query unmet-deps <id>` - What we're waiting for
- `nimbus-query list [status]` - List tasks
- `nimbus-query info <id>` - Full task details
- `nimbus-query prompt <id>` - Get task prompt

## Architecture

### Queue Data Structure (`queue.json`)
```json
{
  "tasks": [
    {
      "id": "1",
      "name": "Run tests",
      "prompt": "Your instruction",
      "iteration": 1,
      "max_iterations": 50,
      "completion_promise": "Tests passing",
      "depends_on": [],
      "status": "queued",
      "created_at": "2026-02-26T10:00:00Z",
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

### Task States
- `queued` - Ready or waiting for dependencies
- `active` - Currently being processed
- `completed` - Done
- `failed` - Errored (future)

### Hook Flow
1. Check active task for completion promise
2. Find first queued task with dependencies met
3. Activate it and feed prompt back to Claude
4. Repeat when session stops

## Examples

### Simple Chain
```bash
/nimbus "Run tests" --task-id tests --completion-promise "Tests pass"
/nimbus "Build" --depends-on tests --completion-promise "Built"
/nimbus "Deploy" --depends-on build --completion-promise "Deployed"

/nimbus-status  # Watch it go
```

### Multiple Dependencies
```bash
/nimbus "API tests" --task-id api --completion-promise "API tests pass"
/nimbus "UI tests" --task-id ui --completion-promise "UI tests pass"
/nimbus "Deploy" --depends-on "api,ui" --completion-promise "Deployed"
```

## Documentation

- **Quick Start**: `docs/QUICK_START.md` - 30-second overview + examples
- **Full Guide**: `docs/QUEUE.md` - Complete reference
- **Implementation**: `docs/UPGRADE.md` - Architecture details

## Verification

Check system is set up correctly:
```bash
./bin/nimbus-verify
```

## Configuration

The hook is configured in `.claude/settings.json`:
```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/nimbus/hooks/on_nimbus.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

No additional configuration needed.

## Troubleshooting

**Tasks not processing?**
- Check hook is enabled: `grep nimbus .claude/settings.json`
- Verify system: `./bin/nimbus-verify`

**Task stuck in queued?**
- Check dependencies: `/nimbus-query unmet-deps <id>`

**Can't find tasks?**
- List all: `/nimbus-query list all`

**Clear queue (WARNING - destructive):**
- `rm .claude/nimbus/queue.json`

## Future Features

- Multi-worker parallel processing (spawn multiple sessions)
- Task retries and dead letter queues
- Priority queues
- Task timeout/auto-fail
- Webhooks on completion
- Custom task metadata

## Status

✅ Production Ready
✅ All tests passing
✅ Backward compatible
✅ Fully documented

---

**Pattern**: Job Queue (Industry Standard - like Celery, Bull, RQ)
**Created**: 2026-02-26
**Last Updated**: 2026-02-26
