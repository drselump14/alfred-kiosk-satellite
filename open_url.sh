#!/bin/bash
# Run Script action: open (or, with alt, copy) the selected URL.
#   browser   App name passed to `open -a` (default Firefox)
#   action    "copy" when the alt modifier was used
url="$1"
[ -z "$url" ] && exit 0
if [ "${action:-}" = "copy" ]; then
  printf '%s' "$url" | pbcopy
  echo "Copied $url"
  exit 0
fi
open -a "${browser:-Firefox}" "$url"
