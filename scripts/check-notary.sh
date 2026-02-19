#!/bin/bash

# Check if at least one argument is provided
if [ $# -lt 1 ]; then
  echo "Usage: $0 <notarization-id>"
  exit 1
fi

# Get the notarization ID from the first argument
NOTARIZATION_ID="$1"

xcrun notarytool log "$NOTARIZATION_ID" --output-format json --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_ID_PWD"
