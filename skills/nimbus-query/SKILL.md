---
name: nimbus-query
description: Query task status and dependencies (for agents and automation)
disable-model-invocation: true
---

Query task information from the Nimbus queue.

Provides programmatic access to task status, dependencies, and metadata. Designed for agents and automation scripts.

## Usage

```bash
/nimbus-query <COMMAND> [task-id] [OPTIONS]
```

## Commands

### status
```bash
/nimbus-query status <id> [--json]
```

Get task status with information.

**Output:**
- Human-readable: `active - Run tests [5/50 iterations]`
- JSON: Structured data with all task fields

**Example:**
```bash
/nimbus-query status 1
# Output: active - Run tests [5/50 iterations]

/nimbus-query status 1 --json
# Output: {"id": "1", "status": "active", "progress": "5/50", ...}
```

### deps-met
```bash
/nimbus-query deps-met <id>
```

Check if all dependencies are completed.

**Output:** `YES` or `NO`
**Exit code:** 0 (YES) or 1 (NO)

**Example:**
```bash
if /nimbus-query deps-met 2; then
  echo "Task 2 can start"
fi
```

### unmet-deps
```bash
/nimbus-query unmet-deps <id>
```

List unmet dependency IDs.

**Output:** Comma-separated IDs (or empty if all met)

**Example:**
```bash
/nimbus-query unmet-deps 2
# Output: 1,3
```

### info
```bash
/nimbus-query info <id>
```

Get full task data as JSON.

### prompt
```bash
/nimbus-query prompt <id>
```

Get the task's prompt text.

### all
```bash
/nimbus-query all <id>
```

Get formatted task details.

### list
```bash
/nimbus-query list [status]
```

List all tasks or filter by status.

**Status values:** `queued`, `active`, `completed`, `failed`

## Agent Workflow Example

```bash
#!/bin/bash

# Check if previous task completed
STATUS=$(/nimbus-query status 1 --json | jq -r '.status')
if [[ "$STATUS" == "completed" ]]; then
  echo "Task 1 complete, proceeding..."
fi

# Check if dependencies are met
if /nimbus-query deps-met 2 > /dev/null; then
  echo "Task 2 dependencies satisfied"
fi

# Find what we're waiting for
UNMET=$(/nimbus-query unmet-deps 2)
if [[ -n "$UNMET" ]]; then
  echo "Task 2 waiting for: $UNMET"
fi

# Get task info as JSON for programmatic use
/nimbus-query info 1 | jq '.completion_promise'
```

## Exit Codes

- `0` - Success (or YES for yes/no commands)
- `1` - Failure (or NO for yes/no commands)

## Related Commands

- `/nimbus` - Add task to queue
- `/nimbus-status` - View all tasks
- `/nimbus-stop` - Remove task

## For Agents

This command is designed for programmatic use by agents. Use structured output (`--json`) for reliable parsing in scripts.

Run the query script:

```bash
bash ./.claude/plugins/nimbus/bin/nimbus-query $ARGUMENTS
```
