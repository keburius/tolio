#!/bin/bash
# Fails if an xcodebuild log contains compiler or linker warnings. Warnings are errors in this project.
set -euo pipefail
log="$1"
warnings=$(grep -E '^[^ ].*: warning: ' "$log" | sort -u || true)
if [[ -n "$warnings" ]]; then
  echo "Build produced warnings:"
  echo "$warnings"
  exit 1
fi
echo "No warnings."
