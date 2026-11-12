#!/bin/bash
# Fails if an xcodebuild log contains compiler or linker warnings in Omni's own code.
# Warnings inside Vendor/ (unmodified third-party code, see Vendor/README.md) are
# listed for visibility but don't fail the build.
set -euo pipefail
log="$1"
all=$(grep -E '^[^ ].*: warning: ' "$log" | sed 's/\x1b\[[0-9;]*m//g' | sort -u || true)
vendored=$(grep -E '/Vendor/' <<<"$all" || true)
own=$(grep -vE '/Vendor/' <<<"$all" || true)
if [[ -n "$vendored" ]]; then
  echo "Vendored code warnings (not failing the build):"
  echo "$vendored"
fi
if [[ -n "$own" ]]; then
  echo "Build produced warnings:"
  echo "$own"
  exit 1
fi
echo "No warnings in Omni code."
