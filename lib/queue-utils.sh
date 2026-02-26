#!/bin/bash

# Nimbus Queue Utilities - Helper functions for task queue management

set -euo pipefail

QUEUE_FILE=".claude/plugins/nimbus/queue.json"

# Initialize queue if it doesn't exist
queue_init() {
  if [[ ! -f "$QUEUE_FILE" ]]; then
    mkdir -p .claude
    echo '{"tasks": []}' > "$QUEUE_FILE"
  fi
}

# Add task to queue
queue_add_task() {
  local id="$1"
  local name="$2"
  local prompt="$3"
  local max_iterations="${4:-50}"
  local completion_promise="${5:-}"
  local depends_on="${6:-}"

  queue_init

  # Build depends_on JSON array
  local depends_json="[]"
  if [[ -n "$depends_on" ]]; then
    # Convert comma-separated string to JSON array
    depends_json=$(echo "$depends_on" | tr ',' '\n' | jq -Rs 'split("\n")[:-1]')
  fi

  # Completion promise JSON
  local promise_json="null"
  if [[ -n "$completion_promise" ]]; then
    promise_json="\"$completion_promise\""
  fi

  # Add task to queue
  jq --arg id "$id" \
     --arg name "$name" \
     --arg prompt "$prompt" \
     --argjson max_iter "$max_iterations" \
     --argjson promise "$promise_json" \
     --argjson depends "$depends_json" \
     '.tasks += [{
       "id": $id,
       "name": $name,
       "prompt": $prompt,
       "iteration": 1,
       "max_iterations": $max_iter,
       "completion_promise": $promise,
       "depends_on": $depends,
       "status": "queued",
       "created_at": now | todate,
       "started_at": null,
       "completed_at": null
     }]' "$QUEUE_FILE" > "$QUEUE_FILE.tmp"

  mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# Get task by ID
queue_get_task() {
  local id="$1"
  jq ".tasks[] | select(.id == \"$id\")" "$QUEUE_FILE"
}

# Update task field
queue_update_task() {
  local id="$1"
  local field="$2"
  local value="$3"

  # Handle different value types
  if [[ "$field" == "status" ]] || [[ "$field" == "completion_promise" ]]; then
    # String values
    jq ".tasks[] |= if .id == \"$id\" then .$field = \"$value\" else . end" "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
  elif [[ "$field" == "iteration" ]]; then
    # Numeric values
    jq ".tasks[] |= if .id == \"$id\" then .$field = $value else . end" "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
  else
    # Default: treat as string with quotes
    jq ".tasks[] |= if .id == \"$id\" then .$field = \"$value\" else . end" "$QUEUE_FILE" > "$QUEUE_FILE.tmp"
  fi

  mv "$QUEUE_FILE.tmp" "$QUEUE_FILE"
}

# Find next eligible task (queued status + dependencies met)
queue_find_next_task() {
  local next_id=""

  # Get all queued tasks
  local queued_tasks=$(jq -r '.tasks[] | select(.status == "queued") | .id' "$QUEUE_FILE")

  for task_id in $queued_tasks; do
    # Check if all dependencies are completed
    local task=$(jq ".tasks[] | select(.id == \"$task_id\")" "$QUEUE_FILE")
    local depends_on=$(echo "$task" | jq -r '.depends_on[]? // empty')

    local all_deps_met=true
    for dep_id in $depends_on; do
      local dep_status=$(jq -r ".tasks[] | select(.id == \"$dep_id\") | .status" "$QUEUE_FILE")
      if [[ "$dep_status" != "completed" ]]; then
        all_deps_met=false
        break
      fi
    done

    if [[ "$all_deps_met" == "true" ]]; then
      next_id="$task_id"
      break
    fi
  done

  echo "$next_id"
}

# Get task prompt
queue_get_prompt() {
  local id="$1"
  jq -r ".tasks[] | select(.id == \"$id\") | .prompt" "$QUEUE_FILE"
}

# Check if task has unmet dependencies
queue_has_unmet_deps() {
  local id="$1"

  local task=$(jq ".tasks[] | select(.id == \"$id\")" "$QUEUE_FILE")
  local depends_on=$(echo "$task" | jq -r '.depends_on[]? // empty')

  for dep_id in $depends_on; do
    local dep_status=$(jq -r ".tasks[] | select(.id == \"$dep_id\") | .status" "$QUEUE_FILE")
    if [[ "$dep_status" != "completed" ]]; then
      return 0  # Has unmet deps
    fi
  done

  return 1  # All deps met
}

# List all tasks with status
queue_list() {
  jq -r '.tasks[] | "\(.id | ljust(4)) | \(.name | ljust(30)) | \(.status | ljust(12)) | deps: \(.depends_on | @csv)"' "$QUEUE_FILE" | column -t -s '|'
}

# Export functions for sourcing
export -f queue_init
export -f queue_add_task
export -f queue_get_task
export -f queue_update_task
export -f queue_find_next_task
export -f queue_get_prompt
export -f queue_has_unmet_deps
export -f queue_list
