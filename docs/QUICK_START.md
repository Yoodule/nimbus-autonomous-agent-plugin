# Nimbus Quick Start Guide

Fast reference for using the multi-task queue system.

## 30-Second Overview

Nimbus is a **job queue** for autonomous tasks. Add multiple tasks, they queue and execute with dependency support.

```bash
/nimbus "Run tests" --completion-promise "Tests pass"
/nimbus "Deploy" --depends-on 1 --completion-promise "Deployed"
/nimbus-status  # Watch progress
```

## Commands

### Add Task
```bash
/nimbus "What to do" --completion-promise "When done"
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
/nimbus-query status 1           # Human-readable
/nimbus-query status 1 --json    # For agents
/nimbus-query deps-met 2         # Can it start?
/nimbus-query unmet-deps 2       # What's it waiting for?
```

### Stop Task
```bash
/nimbus-stop 1
```

## Examples

### Simple Chain
```bash
# Task 1: Tests
/nimbus "Run pytest" --task-id tests --completion-promise "All tests passing"

# Task 2: Build (waits for tests)
/nimbus "Build Docker image" --task-id build --depends-on tests --completion-promise "Image built"

# Task 3: Deploy (waits for build)
/nimbus "Deploy to staging" --task-id deploy --depends-on build --completion-promise "Live on staging"
```

Queue:
```
tests ✅ → build ⏳ → deploy ⏳
```

### Parallel Tasks
```bash
# Both run independently
/nimbus "Run API tests" --task-id api-tests --completion-promise "API tests pass"
/nimbus "Run UI tests" --task-id ui-tests --completion-promise "UI tests pass"

# Both must complete before deploy
/nimbus "Deploy" --depends-on "api-tests,ui-tests" --completion-promise "Deployed"
```

### Multiple Dependent Chains
```bash
# Chain 1
/nimbus "Run tests" --task-id t1 --completion-promise "Pass"
/nimbus "Build" --task-id t2 --depends-on t1 --completion-promise "Built"

# Chain 2 (independent)
/nimbus "Security scan" --task-id sec --completion-promise "Scan complete"

# Both chains complete before final step
/nimbus "Deploy" --task-id deploy --depends-on "t2,sec" --completion-promise "Deployed"
```

## Completion Promises

A promise is a statement that becomes TRUE when done.

✅ Good:
```bash
--completion-promise "All tests passing"
--completion-promise "Docker image built and pushed"
--completion-promise "Deployment successful and verified"
```

❌ Bad:
```bash
--completion-promise "done"  # Too vague
--completion-promise "started"  # Not completion
```

Output when complete:
```
Your message here about progress...

✅ All tests passing!

<promise>All tests passing</promise>
```

## Monitoring

Check status in another terminal:
```bash
while true; do clear; /nimbus-status; sleep 5; done
```

Or once:
```bash
/nimbus-status
```

## For Agents

Get task info programmatically:

```bash
# Check if task complete
/nimbus-query status 1 --json | jq '.status'  # "completed"

# Can this task start?
/nimbus-query deps-met 2 && echo "Yes" || echo "No"

# What are we waiting for?
/nimbus-query unmet-deps 2  # "1" (waiting for task 1)
```

## Shorthand (No Options)

```bash
# If you don't care about ID/name, it auto-generates
/nimbus "Your task" --completion-promise "Your promise"

# With dependencies
/nimbus "Next task" --depends-on 1 --completion-promise "Done"
```

## Task Status

- `queued` - Ready to run or waiting for dependencies
- `active` - Currently being processed
- `completed` - Done ✅
- `waiting_deps` - Waiting for dependencies (shown in status)

## Tips

1. **Use meaningful promises**: Specific, verifiable statements
2. **Name tasks**: Use `--task-id` for easy reference
3. **Check progress**: `/nimbus-status` while Claude works
4. **Clear queue**: `/nimbus-stop <id>` to remove tasks
5. **Query status**: Use `--json` for scripts

## Common Workflows

### CI/CD Pipeline
```bash
/nimbus "Run tests" --task-id tests --completion-promise "All tests pass"
/nimbus "Build image" --task-id build --depends-on tests --completion-promise "Built"
/nimbus "Deploy staging" --task-id staging --depends-on build --completion-promise "Staging live"
/nimbus "Run smoke tests" --task-id smoke --depends-on staging --completion-promise "Smoke tests pass"
/nimbus "Deploy production" --task-id prod --depends-on smoke --completion-promise "Production live"

/nimbus-status  # Watch it go!
```

### Refactoring Project
```bash
/nimbus "Analyze codebase" --task-id analyze --completion-promise "Analysis complete"
/nimbus "Refactor module A" --task-id a --depends-on analyze --completion-promise "Module A refactored"
/nimbus "Refactor module B" --task-id b --depends-on analyze --completion-promise "Module B refactored"
/nimbus "Run all tests" --task-id test --depends-on "a,b" --completion-promise "All tests pass"
/nimbus "Update docs" --task-id docs --depends-on test --completion-promise "Docs updated"
```

### Batch Work
```bash
# Add multiple independent tasks
/nimbus "Fix bug #1" --completion-promise "Bug #1 fixed"
/nimbus "Fix bug #2" --completion-promise "Bug #2 fixed"
/nimbus "Fix bug #3" --completion-promise "Bug #3 fixed"

# They all run sequentially in the queue
/nimbus-status
```

## Troubleshooting

**Task stuck in "queued"?**
```bash
/nimbus-query unmet-deps <task-id>
```

**Can't remember task IDs?**
```bash
/nimbus-query list all
```

**Need full details?**
```bash
/nimbus-query all <task-id>
```

**Clear everything (WARNING)?**
```bash
rm .claude/plugins/nimbus/nimbus-queue.json
```

## Next Steps

- Full docs: Read `.claude/NIMBUS_QUEUE.md`
- Status reference: `/nimbus-status`
- Help: `/nimbus --help`
- Query help: `/nimbus-query`

---

**Status**: Ready to use
**Pattern**: Industry-standard job queue (like Celery, Bull, RQ)
