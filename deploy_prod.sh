#!/bin/bash
echo "Are you sure you want to deploy to production? (y/n)"
read answer
if [ "$answer" != "y" ]; then
  echo "Deployment cancelled."
  exit 1
fi
cdk --profile smartsuite deploy prod/* --hotswap-fallback
