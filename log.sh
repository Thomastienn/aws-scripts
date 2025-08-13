#!/bin/bash

# Usage: ./cwlogs_query.sh <partial-log-group-name>
# Finds log groups containing the pattern and runs a query on the first match found.

PROFILE="smartsuite"  # Change this to your AWS CLI profile name

if [ $# -ne 1 ]; then
  echo "Usage: $0 <partial-log-group-name>"
  exit 1
fi

PARTIAL_LOG_GROUP=$1

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
  if [[ "$lg" == *"$PARTIAL_LOG_GROUP"* ]]; then
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

# Function to fetch and display logs
fetch_logs() {
    local query_id
    local status
    local numLogs=100
    
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
trap 'echo -e "\n\nExiting..."; exit 0' SIGINT

echo ""
echo "Starting continuous log monitoring..."
echo "Press Enter to refresh, Ctrl-C to exit"
echo ""

# Initial fetch
fetch_logs

# Main loop - wait for Enter key
while true; do
    read -r
    fetch_logs
done
