---
name: nimbus-stop
description: Remove or cancel a task from the Nimbus queue
disable-model-invocation: true
---

Remove a task from the Nimbus queue.

Cancels task execution and removes it from the work queue.

## Usage

```bash
/nimbus-stop <task-id>
```

## Arguments

- `<task-id>` - The ID of the task to remove

## Examples

```bash
# Remove task 1
/nimbus-stop 1

# Remove task by name
/nimbus-stop docker-build
```

## What Happens

When you stop a task:
1. The task is removed from the queue
2. If the task was active, processing stops
3. The next queued task (with dependencies met) will start on next iteration
4. Task cannot be recovered (removed completely)

## Related Commands

- `/nimbus` - Add task to queue
- `/nimbus-status` - View queue status
- `/nimbus-query` - Query task status

## Safety Note

Stopping a task is permanent. The task is completely removed from the queue and cannot be recovered.

If you accidentally stop a task, you can re-add it with `/nimbus`.

Run the stop script:

```bash
bash ./.claude/plugins/nimbus/bin/nimbus-stop $ARGUMENTS
```
