#!/usr/bin/env bash

echo "Linting Makefile for undocumented targets..."

# Look for targets missing '##' comments
undocumented=$(awk '
  /^[a-zA-Z0-9_-]+:([^=]|$$)/ {
    if (!match($0, /##/)) {
      sub(":.*", "", $0)
      print $1
    }
  }
' Makefile)

if [[ -n "$undocumented" ]]; then
  echo "ERROR: The following targets are missing '##' comments:"
  echo "$undocumented" | sed 's/^/  - /'
  exit 1
else
  echo "All targets are documented!"
fi
