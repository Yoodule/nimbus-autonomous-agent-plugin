# Nimbus Multi-Task Queue System - Implementation Summary

## Overview

Upgraded Nimbus from single-task sequential processing to **industry-standard job queue architecture** supporting:
- ✅ Multiple concurrent queued tasks
- ✅ Task dependency resolution
- ✅ Agent-friendly status queries
- ✅ Clean separation of concerns
- ✅ Backward compatible with existing hooks

## What Changed

### Architecture

**Before**: Single state file (`.claude/nimbus.local.md`)
```
One task at a time, sequential
```

**After**: Job queue pattern (`.claude/plugins/nimbus/nimbus-queue.json`)
```
Multiple tasks queued + dependency management
Producer → Queue → Single Worker (hook) → Process
```

## New Files

### Core Queue System
| File | Purpose |
|------|---------|
| `.claude/plguins/nimbus/nimbus-queue.json` | Central task queue (JSON) |
| `.claude/queue-utils.sh` | Utility functions for queue management |
| `.claude/hooks/on_nimbus.sh` | **ENHANCED** - Now processes queue with dependency resolution |
| `.claude/scripts/nimbus-start` | **REWRITTEN** - Add tasks to queue |
| `.claude/scripts/nimbus-status` | **NEW** - View queue status |
| `.claude/scripts/nimbus-stop` | **NEW** - Remove/cancel tasks |
| `.claude/scripts/nimbus-query` | **NEW** - Query task status for agents |
| `.claude/NIMBUS_QUEUE.md` | Complete documentation |
| `.claude/NIMBUS_UPGRADE.md` | This file |

## Usage Examples

### Add a Task
```bash
/nimbus "Run all tests" --completion-promise "All tests passing"
```

### Add Dependent Task
```bash
/nimbus "Deploy staging" --depends-on 1 --completion-promise "Deployed"
```

### View Queue
```bash
/nimbus-status
```

### Agent Queries
```bash
# Check status
/nimbus-query status 1

# Check if dependencies are met
/nimbus-query deps-met 2

# Get JSON for programmatic use
/nimbus-query status 1 --json

# Find unmet dependencies
/nimbus-query unmet-deps 2
```

## Key Features

### 1. Task Queueing
- Add multiple tasks without blocking
- Tasks execute sequentially but can be queued in any order
- No need for single active loop

### 2. Dependency Resolution
```bash
Task 1 (tests) → Task 2 (build) → Task 3 (deploy)
     ✅              ⏳              ⏳
```

Task 2 waits for Task 1 to complete. Task 3 waits for Task 2.

### 3. Agent-Friendly Queries
```bash
# Human-readable
/nimbus-query status 1
# Output: active - Run tests [5/50 iterations]

# JSON for agents
/nimbus-query status 1 --json
# Output: {"id": "1", "status": "active", "progress": "5/50", ...}
```

### 4. Task Independence
Each task has its own:
- Completion promise
- Max iterations
- Dependencies
- Iteration counter
- Creation/start/completion timestamps

## Data Structure

```json
{
  "tasks": [
    {
      "id": "1",
      "name": "Run tests",
      "prompt": "Your instruction here",
      "iteration": 1,
      "max_iterations": 50,
      "completion_promise": "All tests passing",
      "depends_on": [],
      "status": "queued",
      "created_at": "2026-02-26T10:00:00Z",
      "started_at": null,
      "completed_at": null
    }
  ]
}
```

## Hook Flow

The enhanced `on_nimbus.sh` hook now:

1. **Check active task** - If processing, look for completion promise
2. **Mark complete** - If promise detected, change status to completed
3. **Find next eligible** - Find first queued task with dependencies met
4. **Activate** - Change status to active, feed prompt back to Claude
5. **Repeat** - Continue until queue is empty

```
┌─────────────────────────────────────┐
│     Task Queue (nimbus-queue.json)  │
├─────────────────────────────────────┤
│ Task 1: tests        → ✅ completed │
│ Task 2: build        → 🔄 active    │
│ Task 3: deploy       → ⏳ queued     │
│ Task 4: smoke-tests  → ⏳ queued     │
└─────────────────────────────────────┘
          ↓
    on_nimbus.sh hook
    (processes Task 2)
```

## Backward Compatibility

- ✅ Old `nimbus.local.md` can coexist (ignored if queue exists)
- ✅ Same completion promise mechanism
- ✅ Same settings.json hook configuration
- ✅ No breaking changes to existing APIs

## Command Reference

### /nimbus
```bash
/nimbus "Task description" \
  [--task-id id]             # Auto-generated if not provided
  [--name "Display name"]    # Auto-generated if not provided
  [--max-iterations 50]      # Default: 50
  [--completion-promise "X"] # REQUIRED
  [--depends-on "1,2,3"]     # Optional dependencies
```

### /nimbus-status
```bash
/nimbus-status  # Shows all tasks with status and details
```

### /nimbus-stop
```bash
/nimbus-stop <task-id>  # Remove task from queue
```

### /nimbus-query
```bash
# Status queries
/nimbus-query status <id> [--json]
/nimbus-query deps-met <id>
/nimbus-query unmet-deps <id>

# Data retrieval
/nimbus-query info <id>      # Full JSON object
/nimbus-query prompt <id>    # Task prompt
/nimbus-query all <id>       # Pretty-printed details
/nimbus-query list [status]  # List tasks
```

## Agent Integration

Agents can programmatically check task status:

```bash
#!/bin/bash

# Only proceed if previous task is complete
STATUS=$(/nimbus-query status 1 --json | jq -r '.status')
if [[ "$STATUS" == "completed" ]]; then
  echo "Task 1 complete, proceeding..."
fi

# Check if dependencies are met before starting
if /nimbus-query deps-met 2 > /dev/null; then
  echo "Task 2 dependencies satisfied"
fi

# Find what we're waiting for
UNMET=$(/nimbus-query unmet-deps 2)
if [[ -n "$UNMET" ]]; then
  echo "Task 2 waiting for: $UNMET"
fi
```

## Benefits

### For Users
- ✅ Queue multiple tasks without blocking
- ✅ Define task chains and pipelines
- ✅ Visual task status with `/nimbus-status`
- ✅ Easy task cancellation

### For Agents
- ✅ Programmatic task queries
- ✅ Structured JSON status
- ✅ Dependency visibility
- ✅ Conditional task execution

### For System Design
- ✅ Industry-standard job queue pattern
- ✅ Scalable to multiple workers
- ✅ Clear separation of concerns
- ✅ Extensible data structure

## Future Enhancements

The queue-based design enables:

1. **Multi-worker support** - Spawn multiple Claude sessions
2. **Task retries** - Automatic retry on failure
3. **Priority queues** - Schedule high-priority tasks first
4. **Task timeout** - Auto-fail tasks exceeding max iterations
5. **Dead letter queue** - Track failed tasks separately
6. **Task metadata** - Custom fields for task tracking
7. **Webhooks** - Notifications on task completion

## Migration Path

If you have existing `nimbus.local.md`:

1. **Option A: Continue using old system** - It still works
2. **Option B: Migrate to queue**:
   ```bash
   # Read old nimbus.local.md
   cat .claude/nimbus.local.md

   # Add as new task
   /nimbus "Your task" --completion-promise "Your phrase"

   # Remove old file
   rm .claude/nimbus.local.md
   ```

## Troubleshooting

### Queue Not Processing
Check if hook is active:
```bash
grep "Stop" .claude/settings.json
```

### Task Stuck in Queued
Check dependencies:
```bash
/nimbus-query unmet-deps <task-id>
```

### Clear Everything
```bash
rm .claude/plugins/nimbus/nimbus-queue.json
```

## Files Summary

```
.claude/
├── nimbus-queue.json           # Central queue (user-managed)
├── queue-utils.sh              # Utility functions
├── hooks/
│   └── on_nimbus.sh            # Task processor (enhanced)
├── scripts/
│   ├── nimbus-start            # Add tasks (rewritten)
│   ├── nimbus-status           # View queue (new)
│   ├── nimbus-stop             # Cancel tasks (new)
│   └── nimbus-query            # Query status (new)
├── NIMBUS_QUEUE.md             # Full documentation
└── NIMBUS_UPGRADE.md           # This file
```

## Settings

No configuration changes needed. The hook automatically:
- Detects if queue file exists
- Switches to queue mode
- Manages task lifecycle
- Handles dependencies

## Support

For questions or issues:
1. Check `.claude/NIMBUS_QUEUE.md` for detailed docs
2. Run `/nimbus-status` to see current state
3. Use `/nimbus-query` to debug task issues
4. Review hook logs in `.claude/hooks/on_nimbus.sh`

---

**Implementation Date**: 2026-02-26
**Status**: Production Ready
**Pattern**: Job Queue (Industry Standard)
