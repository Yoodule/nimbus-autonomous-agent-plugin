# Nimbus Multi-Task Queue System

Industry-standard job queue architecture for autonomous task management with dependency resolution.

## Overview

Nimbus now supports **multiple concurrent queued tasks** with full **dependency management**. Instead of running one task to completion, you can queue multiple tasks that execute sequentially with automatic dependency resolution.

### Architecture Pattern

```
Producer (you) → Task Queue (nimbus-queue.json) → Worker (hook) → Process → Mark Complete
```

This follows the standard job queue pattern used by **Celery**, **Bull**, **RQ**, and other industry systems.

## Quick Start

### 1. Add a Task

```bash
/nimbus "Run all tests" --completion-promise "All tests passing"
```

Output:
```
🚀 Task added to Nimbus queue!
Task ID: 1
Name: Run all tests
Status: queued
```

### 2. Add Dependent Task

```bash
/nimbus "Deploy to staging" --depends-on 1 --completion-promise "Deployment complete"
```

This task waits for task 1 to complete before starting.

### 3. Check Queue Status

```bash
/nimbus-status
```

Shows all tasks, their status, dependencies, and progress.

### 4. Query Task Status (for agents)

```bash
# Check if task 2 can start
/nimbus-query deps-met 2  # Returns: YES or NO

# Get status of task 1
/nimbus-query status 1    # Returns: queued, active, completed, etc.

# Find what task 2 is waiting for
/nimbus-query unmet-deps 2  # Returns: comma-separated IDs
```

## Task Lifecycle

```
queued → active → completed
  ↓
[waiting for dependencies]
```

### States

- **queued**: Ready to run or waiting for dependencies
- **active**: Currently being processed
- **completed**: Finished successfully
- **failed**: Errored (future feature)
- **cancelled**: User stopped it

## Command Reference

### /nimbus - Add Task to Queue

```bash
/nimbus "Your task description" \
  --task-id 1                           # Optional: unique ID
  --name "Friendly name"                # Optional: display name
  --max-iterations 50                   # Optional: max iterations
  --completion-promise "Done phrase"    # REQUIRED
  --depends-on "1,2,3"                  # Optional: task IDs to wait for
```

### /nimbus-status - View Queue

```bash
/nimbus-status
```

Shows all tasks with full details and dependency information.

### /nimbus-stop - Remove Task

```bash
/nimbus-stop <task-id>
```

Removes a task from the queue.

### /nimbus-query - Query Task Info (for agents)

```bash
# Get task status
/nimbus-query status <id>              # Returns: queued, active, completed, etc.

# Check if dependencies are met
/nimbus-query deps-met <id>            # Returns: YES or NO

# Get unmet dependencies
/nimbus-query unmet-deps <id>          # Returns: id1,id2,id3

# Get full task info
/nimbus-query info <id>                # Returns: JSON object

# Get task prompt
/nimbus-query prompt <id>              # Returns: task prompt text

# List tasks
/nimbus-query list [status]            # Returns: all tasks or filtered by status

# Get all details
/nimbus-query all <id>                 # Returns: formatted task details
```

## Completion Promises

Each task must have a **completion promise** - a phrase that becomes TRUE when done.

### Requirements

- Must be a genuine statement of completion
- Output as: `<promise>Your promise phrase</promise>`
- Only output when the statement is TRUE
- Do NOT lie to exit the loop

### Examples

```bash
# Test task
/nimbus "Run tests" --completion-promise "All tests passing"
# Complete with: <promise>All tests passing</promise>

# Deployment task
/nimbus "Deploy app" --completion-promise "Deployment successful and verified"
# Complete with: <promise>Deployment successful and verified</promise>

# Build task
/nimbus "Build Docker image" --completion-promise "Image built and pushed"
# Complete with: <promise>Image built and pushed</promise>
```

## Task Dependencies

Create task chains where later tasks wait for earlier ones.

### Example: Full CI/CD Pipeline

```bash
# Step 1: Run tests
/nimbus "Run all tests" \
  --task-id tests \
  --completion-promise "All tests passing"

# Step 2: Build (waits for tests)
/nimbus "Build Docker image" \
  --task-id build \
  --depends-on tests \
  --completion-promise "Image built and pushed"

# Step 3: Deploy staging (waits for build)
/nimbus "Deploy to staging" \
  --task-id deploy-staging \
  --depends-on build \
  --completion-promise "Staging deployment verified"

# Step 4: Run smoke tests (waits for staging)
/nimbus "Run smoke tests" \
  --task-id smoke-tests \
  --depends-on deploy-staging \
  --completion-promise "Smoke tests passing"

# Step 5: Deploy production (waits for smoke tests)
/nimbus "Deploy to production" \
  --task-id deploy-prod \
  --depends-on smoke-tests \
  --completion-promise "Production deployment verified"
```

Queue status:
```
1. tests               ✅ COMPLETED
   → 2. build          ✅ COMPLETED
      → 3. deploy-staging ✅ COMPLETED
         → 4. smoke-tests ✅ COMPLETED
            → 5. deploy-prod ⏳ ACTIVE
```

## How It Works

### Hook Flow

1. **Check active task**: If a task is active, check if it sent a completion promise
2. **Mark complete**: If promise detected or max iterations reached, mark as completed
3. **Find next eligible**: Find first queued task with all dependencies met
4. **Activate next**: Change status to active, feed prompt back to Claude
5. **Repeat**: When session stops, hook re-activates and continues

### Worker Pattern

The hook acts as a **single-worker queue processor**:
- Processes one task at a time
- Tasks run sequentially but can be queued independently
- Dependency resolution is automatic
- Can be extended to multiple workers in future

## Queue Data Structure

```json
{
  "tasks": [
    {
      "id": "1",
      "name": "Run all tests",
      "prompt": "Run pytest and verify all tests pass...",
      "iteration": 5,
      "max_iterations": 50,
      "completion_promise": "All tests passing",
      "depends_on": [],
      "status": "completed",
      "created_at": "2026-02-26T10:00:00Z",
      "started_at": "2026-02-26T10:01:00Z",
      "completed_at": "2026-02-26T10:15:00Z"
    },
    {
      "id": "2",
      "name": "Deploy to staging",
      "prompt": "Deploy application to staging...",
      "iteration": 1,
      "max_iterations": 50,
      "completion_promise": "Deployment successful",
      "depends_on": ["1"],
      "status": "active",
      "created_at": "2026-02-26T10:01:30Z",
      "started_at": "2026-02-26T10:16:00Z",
      "completed_at": null
    }
  ]
}
```

## Best Practices

### 1. Use Meaningful Completion Promises
```bash
# ✅ Good: specific and verifiable
--completion-promise "All 96 tests passing"

# ❌ Bad: vague
--completion-promise "done"
```

### 2. Chain Related Tasks
```bash
# ✅ Good: logical sequence
tests → build → deploy → verify

# ❌ Bad: unrelated tasks with same ID
tests → random-task → another-task
```

### 3. Check Status During Development
```bash
# Monitor progress while Claude is working
watch -n 5 '/nimbus-status'
```

### 4. Use Named Task IDs
```bash
# ✅ Good: descriptive
--task-id test-api
--task-id deploy-staging
--task-id smoke-tests

# ❌ Bad: cryptic
--task-id t1
--task-id t2
```

## Advanced: Agent-Driven Task Checking

Agents can programmatically check task status:

```bash
#!/bin/bash

# Only proceed if previous task completed
if [[ $(/nimbus-query status 1) == "completed" ]]; then
  echo "Task 1 complete, proceeding..."
else
  echo "Task 1 not complete yet"
fi

# Check if all dependencies are met
if /nimbus-query deps-met 2 > /dev/null; then
  echo "Task 2 can start"
else
  UNMET=$(/nimbus-query unmet-deps 2)
  echo "Task 2 waiting for: $UNMET"
fi

# Get task info as JSON for programmatic use
/nimbus-query info 1 | jq '.status'
```

## Future: Multi-Worker Support

The current implementation is a **single-worker** queue processor. Future versions could:

- Spawn multiple Claude sessions as workers
- Process multiple tasks in parallel
- Add load balancing across workers
- Support priority queues
- Add task retries and dead letter queues

All of this uses the same queue data structure and is backward compatible.

## Troubleshooting

### Task Stuck in "queued"
Check dependencies:
```bash
/nimbus-query unmet-deps <task-id>
```

### Can't Find Task
List all tasks:
```bash
/nimbus-query list all
```

### Task Not Processing
Check active task:
```bash
/nimbus-status
```

If no active task, the queue may be waiting for dependencies or between iterations.

### Clear Queue
Remove all tasks (WARNING: destructive):
```bash
rm .claude/plugins/nimbus/nimbus-queue.json
```

## Files

- `.claude/plugins/nimbus/nimbus-queue.json` - Task queue data
- `.claude/queue-utils.sh` - Queue management utilities
- `.claude/hooks/on_nimbus.sh` - Stop hook (task processor)
- `.claude/scripts/nimbus-start` - Add tasks
- `.claude/scripts/nimbus-status` - View queue
- `.claude/scripts/nimbus-stop` - Remove tasks
- `.claude/scripts/nimbus-query` - Query task status
- `.claude/NIMBUS_QUEUE.md` - This documentation
