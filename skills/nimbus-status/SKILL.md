---
name: nimbus-status
description: View the Nimbus task queue and progress
disable-model-invocation: true
---

View the current state of the Nimbus task queue.

Shows all tasks with their status, progress, and dependencies.

## Usage

```bash
/nimbus-status
```

## Output

Displays:
- All tasks in the queue
- Current status (queued, active, completed)
- Iteration progress (current/max)
- Task dependencies
- Task creation and completion times

## Example Output

```
📋 Nimbus Queue Status
═══════════════════════════════════════════════════════════════════════════════

ID: 1
  Name:               Run tests
  Status:             completed
  Iteration:          5/50
  Completion promise: Tests passing
  Dependencies:       none
  Created:            2026-02-26T10:00:00Z
  Started:            2026-02-26T10:01:00Z
  Completed:          2026-02-26T10:05:00Z

ID: 2
  Name:               Build Docker
  Status:             active
  Iteration:          2/50
  Completion promise: Image built
  Dependencies:       1
  Created:            2026-02-26T10:01:30Z
  Started:            2026-02-26T10:06:00Z

═══════════════════════════════════════════════════════════════════════════════

Summary:
  Active:    1
  Queued:    2
  Completed: 1
  Failed:    0
  Total:     4
```

## Related Commands

- `/nimbus` - Add task to queue
- `/nimbus-stop` - Remove task from queue
- `/nimbus-query` - Query task status (for agents)

Run the status script:

```bash
bash ./.claude/plugins/nimbus/bin/nimbus-status $ARGUMENTS
```
