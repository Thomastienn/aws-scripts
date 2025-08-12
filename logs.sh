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

# Prepare query parameters
QUERY='fields @timestamp, @message | sort @timestamp desc | limit 20'
END_TIME=$(date +%s)
START_TIME=$((END_TIME - 3600))

echo "Starting CloudWatch Logs Insights query..."

QUERY_ID=$(aws logs start-query \
  --profile "$PROFILE" \
  --log-group-name "$EXACT_LOG_GROUP" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --query-string "$QUERY" \
  --query 'queryId' \
  --output text)

echo "Query started with ID: $QUERY_ID"

STATUS="Running"
while [[ "$STATUS" == "Running" || "$STATUS" == "Scheduled" ]]; do
  sleep 2
  STATUS=$(aws logs get-query-results \
    --profile "$PROFILE" \
    --query-id "$QUERY_ID" \
    --query 'status' \
    --output text)
  echo "Query status: $STATUS"
done

if [[ "$STATUS" == "Complete" ]]; then
    DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    aws logs get-query-results \
        --profile "$PROFILE" \
        --query-id "$QUERY_ID" \
        --output json | jq '.' | python "$DIR/_parseLog.py"
else
  echo "Query ended with status: $STATUS"
  exit 4
fi
