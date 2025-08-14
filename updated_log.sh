#!/bin/bash

# Usage: ./cwlogs_query.sh <partial-log-group-name>
# Finds log groups containing the pattern and runs a query on the first match found.

PROFILE="smartsuite"  # Change this to your AWS CLI profile name

if [ $# -ne 1 ]; then
  echo "Usage: $0 <partial-log-group-name>"
  exit 1
fi

PARTIAL_LOG_GROUP=$1
BRANCH=${2:-"dev"}

echo "Searching for log groups containing pattern: '$PARTIAL_LOG_GROUP'"

# Get all log groups (handle pagination)
LOG_GROUPS=()
NEXT_TOKEN=""

while : ; do
  if [ -z "$NEXT_TOKEN" ]; then
    response=$(aws logs describe-log-groups --profile "$PROFILE" --output json)
  else
    response=$(aws logs describe-log-groups --profile "$PROFILE" --next-token "$NEXT_TOKEN" --output json)
  fi

  groups=$(echo "$response" | jq -r '.logGroups[].logGroupName')
  LOG_GROUPS+=($groups)

  NEXT_TOKEN=$(echo "$response" | jq -r '.nextToken // empty')
  if [ -z "$NEXT_TOKEN" ]; then
    break
  fi
done

# Filter log groups by substring match (case sensitive)
MATCHES=()
for lg in "${LOG_GROUPS[@]}"; do
  if [[ "$lg" == "$BRANCH"*"$PARTIAL_LOG_GROUP"* ]]; then
    MATCHES+=("$lg")
  fi
done

# Use the first matched log group automatically
if [ ${#MATCHES[@]} -eq 0 ]; then
  echo "No log groups found containing '$PARTIAL_LOG_GROUP'."
  exit 2
else
  EXACT_LOG_GROUP="${MATCHES[0]}"
  echo "Using log group: $EXACT_LOG_GROUP"
fi

# Find the newest log stream to display which one we're targeting
echo "Finding newest log stream in: $EXACT_LOG_GROUP"
NEWEST_STREAM=$(aws logs describe-log-streams \
  --profile "$PROFILE" \
  --log-group-name "$EXACT_LOG_GROUP" \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --query 'logStreams[0].logStreamName' \
  --output text 2>/dev/null)

echo "Targeting newest log stream: $NEWEST_STREAM"

# Global variables for log group switching
NEW_LOG_GROUP_FOUND=""
LOG_GROUP_CHECK_PID=""

# Function to check for newer log groups in background (runs once)
check_for_newer_log_groups() {
    # Get all log groups again
    local current_log_groups=()
    local next_token=""
    
    while : ; do
        if [ -z "$next_token" ]; then
            local response=$(aws logs describe-log-groups --profile "$PROFILE" --output json 2>/dev/null)
        else
            local response=$(aws logs describe-log-groups --profile "$PROFILE" --next-token "$next_token" --output json 2>/dev/null)
        fi
        
        if [ $? -ne 0 ]; then
            break  # Skip this check if AWS call fails
        fi
        
        local groups=$(echo "$response" | jq -r '.logGroups[].logGroupName' 2>/dev/null)
        current_log_groups+=($groups)
        
        next_token=$(echo "$response" | jq -r '.nextToken // empty' 2>/dev/null)
        if [ -z "$next_token" ]; then
            break
        fi
    done
    
    # Filter for matching log groups
    local current_matches=()
    for lg in "${current_log_groups[@]}"; do
        if [[ "$lg" == *"$PARTIAL_LOG_GROUP"* ]]; then
            current_matches+=("$lg")
        fi
    done
    
    # Sort matches to get the newest (assuming lexicographic sorting works for timestamps in names)
    if [ ${#current_matches[@]} -gt 0 ]; then
        # Sort and get the first (newest) match
        local newest_match=$(printf '%s\n' "${current_matches[@]}" | sort -r | head -n1)
        
        # Check if we found a different (presumably newer) log group
        if [[ "$newest_match" != "$EXACT_LOG_GROUP" ]]; then
            NEW_LOG_GROUP_FOUND="$newest_match"
        fi
    fi
}

# Function to fetch and display logs
fetch_logs() {
    local query_id
    local status
    local numLogs=100
    
    # Kill any existing background check process to ensure only one runs
    if [[ -n "$LOG_GROUP_CHECK_PID" ]] && kill -0 "$LOG_GROUP_CHECK_PID" 2>/dev/null; then
        kill "$LOG_GROUP_CHECK_PID" 2>/dev/null
        wait "$LOG_GROUP_CHECK_PID" 2>/dev/null
    fi
    
    # Start background check for newer log groups
    check_for_newer_log_groups &
    LOG_GROUP_CHECK_PID=$!
    
    # Check if we should switch to a newer log group
    if [[ -n "$NEW_LOG_GROUP_FOUND" ]]; then
        echo "Switching to newer log group: $NEW_LOG_GROUP_FOUND"
        EXACT_LOG_GROUP="$NEW_LOG_GROUP_FOUND"
        NEW_LOG_GROUP_FOUND=""  # Clear the flag
        
        # Update newest stream info
        NEWEST_STREAM=$(aws logs describe-log-streams \
          --profile "$PROFILE" \
          --log-group-name "$EXACT_LOG_GROUP" \
          --order-by LastEventTime \
          --descending \
          --max-items 1 \
          --query 'logStreams[0].logStreamName' \
          --output text 2>/dev/null)
    fi
    
    # Use CloudWatch Logs Insights with recent time window to get newest logs
    QUERY="fields @timestamp, @message, @logStream | sort @timestamp desc | limit $numLogs"
    END_TIME=$(date +%s)
    START_TIME=$((END_TIME - 1800))  # Last 30 minutes
    
    echo "Fetching $numLogs newest logs..."
    
    query_id=$(aws logs start-query \
      --profile "$PROFILE" \
      --log-group-name "$EXACT_LOG_GROUP" \
      --start-time "$START_TIME" \
      --end-time "$END_TIME" \
      --query-string "$QUERY" \
      --query 'queryId' \
      --output text)
    
    # Wait for query to complete
    status="Running"
    while [[ "$status" == "Running" || "$status" == "Scheduled" ]]; do
        sleep 1
        status=$(aws logs get-query-results \
          --profile "$PROFILE" \
          --query-id "$query_id" \
          --query 'status' \
          --output text)
    done
    
    # Display results
    if [[ "$status" == "Complete" ]]; then
        clear
        echo "=== Log group: $EXACT_LOG_GROUP ==="
        echo "=== Newest log stream: $NEWEST_STREAM ==="
        if [[ -n "$NEW_LOG_GROUP_FOUND" ]]; then
            echo "=== (Newer log group found: $NEW_LOG_GROUP_FOUND - will switch on next refresh) ==="
        fi
        echo "=== $numLogs Newest Logs (Updated: $(date '+%Y-%m-%d %H:%M:%S')) ==="
        echo ""
        
        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        aws logs get-query-results \
            --profile "$PROFILE" \
            --query-id "$query_id" \
            --output json | jq '.' | python "$DIR/_parseLog.py"
            
        echo ""
        echo "=== Press Enter to refresh logs, Ctrl-C to exit ==="
    else
        echo "Query failed with status: $status"
    fi
}

# Set up signal handler for clean exit
cleanup() {
    echo -e "\n\nExiting..."
    # Kill background process if running
    if [[ -n "$LOG_GROUP_CHECK_PID" ]] && kill -0 "$LOG_GROUP_CHECK_PID" 2>/dev/null; then
        kill "$LOG_GROUP_CHECK_PID" 2>/dev/null
        wait "$LOG_GROUP_CHECK_PID" 2>/dev/null
    fi
    exit 0
}
trap cleanup SIGINT

echo ""
echo "Starting continuous log monitoring..."
echo "Will check for newer log groups on each refresh"
echo "Press Enter to refresh, Ctrl-C to exit"
echo ""

# Initial fetch
fetch_logs

# Main loop - wait for Enter key
while true; do
    read -r
    fetch_logs
done
