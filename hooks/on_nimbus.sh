#!/bin/bash

# Nimbus: Multi-Task Autonomous Agent Stop Hook
# Manages task queue with dependency resolution
# Prevents session exit when autonomous loop is active
# Processes tasks sequentially from queue

set -euo pipefail

# Source queue utilities
source "$(dirname "${BASH_SOURCE[0]}")/../lib/queue-utils.sh"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Initialize queue
queue_init

QUEUE_FILE=".claude/plugins/nimbus/queue.json"

# Check if queue has any tasks
TASK_COUNT=$(jq '.tasks | length' "$QUEUE_FILE")

if [[ $TASK_COUNT -eq 0 ]]; then
  # No active loop - allow exit
  exit 0
fi

# Check if any task is active or has pending work
ACTIVE_TASK=$(jq -r '.tasks[] | select(.status == "active") | .id' "$QUEUE_FILE" | head -1)
QUEUED_TASK=$(jq -r '.tasks[] | select(.status == "queued") | .id' "$QUEUE_FILE" | head -1)

if [[ -z "$ACTIVE_TASK" ]] && [[ -z "$QUEUED_TASK" ]]; then
  # No active or queued tasks - all done or all waiting for deps
  # Check if there are any waiting tasks (with unmet deps)
  WAITING_TASKS=$(jq -r '.tasks[] | select(.status == "queued") | .id' "$QUEUE_FILE" | wc -l)
  if [[ $WAITING_TASKS -eq 0 ]]; then
    exit 0
  fi
fi

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Nimbus: Transcript not found, exiting queue loop" >&2
  exit 0
fi

# ============================================================================
# Handle Active Task - Check for completion
# ============================================================================

if [[ -n "$ACTIVE_TASK" ]]; then
  # Get active task details
  TASK_DATA=$(jq ".tasks[] | select(.id == \"$ACTIVE_TASK\")" "$QUEUE_FILE")
  MAX_ITERATIONS=$(echo "$TASK_DATA" | jq -r '.max_iterations')
  ITERATION=$(echo "$TASK_DATA" | jq -r '.iteration')
  COMPLETION_PROMISE=$(echo "$TASK_DATA" | jq -r '.completion_promise // empty')
  TASK_NAME=$(echo "$TASK_DATA" | jq -r '.name')

  # Read last assistant message from transcript
  if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
    echo "⚠️  Nimbus [$ACTIVE_TASK/$TASK_NAME]: No assistant message found" >&2
    exit 0
  fi

  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)

  LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
    .message.content |
    map(select(.type == "text")) |
    map(.text) |
    join("\n")
  ' 2>&1 || echo "")

  # Check for completion promise
  PROMISE_DETECTED=false
  if [[ -n "$COMPLETION_PROMISE" ]]; then
    PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

    if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" == "$COMPLETION_PROMISE" ]]; then
      PROMISE_DETECTED=true
      echo "✅ Nimbus [$ACTIVE_TASK/$TASK_NAME]: Detected completion promise"
      queue_update_task "$ACTIVE_TASK" "status" "completed"
      queue_update_task "$ACTIVE_TASK" "completed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    fi
  fi

  # Check if max iterations reached
  if [[ -z "$COMPLETION_PROMISE" ]] && [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
    echo "🛑 Nimbus [$ACTIVE_TASK/$TASK_NAME]: Max iterations ($MAX_ITERATIONS) reached"
    queue_update_task "$ACTIVE_TASK" "status" "completed"
    queue_update_task "$ACTIVE_TASK" "completed_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    PROMISE_DETECTED=true
  fi

  # If task not complete, increment iteration and continue
  if [[ "$PROMISE_DETECTED" == "false" ]]; then
    NEXT_ITERATION=$((ITERATION + 1))
    queue_update_task "$ACTIVE_TASK" "iteration" "$NEXT_ITERATION"
  fi
fi

# ============================================================================
# Find Next Task to Activate
# ============================================================================

NEXT_TASK=$(queue_find_next_task)

if [[ -z "$NEXT_TASK" ]]; then
  # No eligible tasks - check if there are waiting tasks
  WAITING=$(jq -r '.tasks[] | select(.status == "queued") | {id: .id, name: .name, depends_on: .depends_on}' "$QUEUE_FILE")

  if [[ -n "$WAITING" ]]; then
    echo "⏳ Nimbus: All queued tasks waiting for dependencies to complete"
    echo ""
    echo "Waiting tasks:"
    echo "$WAITING" | jq -r '"  • \(.id): \(.name) (waiting for: \(.depends_on | join(", ")))"'
  fi

  exit 0
fi

# Activate next task
echo "🚀 Nimbus: Activating task [$NEXT_TASK]"
NEXT_TASK_DATA=$(jq ".tasks[] | select(.id == \"$NEXT_TASK\")" "$QUEUE_FILE")
NEXT_TASK_NAME=$(echo "$NEXT_TASK_DATA" | jq -r '.name')
NEXT_MAX_ITERATIONS=$(echo "$NEXT_TASK_DATA" | jq -r '.max_iterations')

queue_update_task "$NEXT_TASK" "status" "active"
queue_update_task "$NEXT_TASK" "started_at" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Get prompt for next task
PROMPT_TEXT=$(queue_get_prompt "$NEXT_TASK")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Nimbus: No prompt found for task $NEXT_TASK" >&2
  exit 0
fi

# Build system message
SYSTEM_MSG="🚀 Nimbus task [$NEXT_TASK/$NEXT_TASK_NAME] | iteration 1/$NEXT_MAX_ITERATIONS | To complete: output <promise>COMPLETION_PHRASE</promise> when done (ONLY when TRUE - do not lie!)"

# Output JSON to block stop and feed prompt back
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
