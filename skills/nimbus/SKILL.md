---
name: nimbus
description: Add task to the Nimbus autonomous job queue for continuous execution
disable-model-invocation: true
---

Add a task to the Nimbus multi-task queue system.

This command adds a task to the work queue that will be processed autonomously. Tasks are processed sequentially with automatic dependency resolution. The queue persists across sessions.

## Usage

```bash
/nimbus "Your task description" \
  [--task-id <id>] \
  [--name <display-name>] \
  [--max-iterations <n>] \
  [--completion-promise '<text>'] \
  [--depends-on <id[,id,...]>]
```

## Required Arguments

- **Task description** - What you want Nimbus to work on
- **--completion-promise 'TEXT'** - Output when task is done (REQUIRED)

## Optional Arguments

- `--task-id ID` - Unique task identifier (auto-generated if not provided)
- `--name NAME` - Display name for the task (auto-generated if not provided)
- `--max-iterations N` - Stop after N iterations (default: 50)
- `--depends-on ID[,ID,...]` - Task IDs to wait for before starting

## Completion Promise

The completion promise is a statement that becomes TRUE when the task is done.

When outputting the promise, use this format:
```
<promise>Your promise text</promise>
```

The text MUST match exactly what you specified with `--completion-promise`.

## Examples

### Simple Task
```bash
/nimbus "Run all tests" --completion-promise "All tests passing"
```

### With Dependencies
```bash
/nimbus "Deploy to staging" --depends-on 1 --completion-promise "Deployment complete"
```

### Named Task
```bash
/nimbus "Build Docker image" \
  --task-id docker-build \
  --name "Docker Build" \
  --completion-promise "Image built and pushed"
```

### Task Chain
```bash
# Step 1
/nimbus "Run tests" --task-id tests --completion-promise "All tests passing"

# Step 2 (waits for step 1)
/nimbus "Build image" --depends-on tests --completion-promise "Image built"

# Step 3 (waits for step 2)
/nimbus "Deploy" --depends-on build --completion-promise "Live on staging"
```

## Related Commands

- `/nimbus-status` - View queue and task progress
- `/nimbus-stop <id>` - Remove a task from queue
- `/nimbus-query` - Query task status (for agents)

## How It Works

The task is added to `.claude/plugins/nimbus/queue.json` and will be processed when:
1. All dependencies (if any) are completed
2. The current active task completes or reaches max iterations

Tasks are processed sequentially in the queue. The stop hook automatically detects when a task completes and moves to the next eligible task.

Run the setup script:

```bash
bash ./.claude/plugins/nimbus/bin/nimbus-start $ARGUMENTS
```
