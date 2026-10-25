#!/usr/bin/env bash
# Renders one step of a wowsim viewer HTML to a PNG via headless Edge/Chrome.
#
# Usage: tools/wowsim/screenshot.sh <viewer.html> <step> <out.png> [zoom] [frame] [WxH]
#   step   1-based step number
#   zoom   viewer zoom (default 1.6)
#   frame  global frame name to scroll into view (default isiLiveMainFrame)
#   WxH    browser window size (default 1500x900)
set -euo pipefail

html="$1"
step="$2"
out="$3"
zoom="${4:-1.6}"
frame="${5:-isiLiveMainFrame}"
size="${6:-1500x900}"

browser=""
for candidate in \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "$(command -v chromium 2>/dev/null || true)" \
  "$(command -v google-chrome 2>/dev/null || true)"; do
  if [ -n "$candidate" ] && [ -x "$candidate" ]; then
    browser="$candidate"
    break
  fi
done
if [ -z "$browser" ]; then
  echo "screenshot.sh: no Edge/Chrome found" >&2
  exit 1
fi

abs="$(cd "$(dirname "$html")" && pwd -W 2>/dev/null || pwd)/$(basename "$html")"
url="file:///${abs// /%20}#step=${step}&zoom=${zoom}&frame=${frame}"
"$browser" --headless=new --disable-gpu --hide-scrollbars --window-size="${size/x/,}" \
  --virtual-time-budget=2000 --screenshot="$out" "$url" >/dev/null 2>&1
echo "$out"
