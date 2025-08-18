#!/bin/bash
BRANCH=${1:-"dev"}
if [ "$BRANCH" != "dev" ] && [ "$BRANCH" != "prod" ]; then
  echo "Usage: $0 [dev|prod]"
  exit 1
fi

run(){
  echo "Deploying to $BRANCH environment..."
  hotswap=""
  if [ "$BRANCH" == "dev" ]; then
    hotswap="--hotswap-fallback"
  fi
  cd ~/smartsuite/ && cdk --profile smartsuite deploy "$BRANCH"/* $hotswap && cd -
}

if [ "$BRANCH" == "prod" ]; then
  echo "Are you sure you want to deploy to production? (y/n)"
  read answer
  if [ "$answer" != "y" ]; then
    exit 1
  fi
fi

run
