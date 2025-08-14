#!/bin/bash
BRANCH=${1:-"dev"}
if [ "$BRANCH" != "dev" ] && [ "$BRANCH" != "prod" ]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

run(){
  echo "Deploying to $BRANCH environment..."
  cdk --profile smartsuite -app ~/smartsuite/ deploy "$BRANCH"/* --hotswap-fallback
}

if [ "$BRANCH" == "dev" ]; then
  run
  exit 0
fi

echo "Are you sure you want to deploy to production? (y/n)"
read answer
if [ "$answer" != "y" ]; then
  exit 1
fi

run
