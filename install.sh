#!/bin/bash
# Update the installed copy of this workflow in place, without re-importing it.
# Re-importing ("Replace") resets the saved Configure Workflow values (prefs.plist);
# this only copies the runtime files and never touches prefs.plist.
#
# The installed folder is found by bundle id under the Alfred preferences folder
# named in ~/Library/Application Support/Alfred/prefs.json (.current).
set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

cd "$(dirname "$0")"
files=(info.plist icon.png script_filter.sh open_url.sh set_token.sh)
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :bundleid' info.plist)"
version="$(/usr/libexec/PlistBuddy -c 'Print :version' info.plist)"

prefs_json="$HOME/Library/Application Support/Alfred/prefs.json"
prefs_dir=""
[ -f "$prefs_json" ] && prefs_dir="$(plutil -extract current raw -o - "$prefs_json" 2>/dev/null || true)"
prefs_dir="${prefs_dir/#\~/$HOME}"
[ -n "$prefs_dir" ] || prefs_dir="$HOME/Library/Application Support/Alfred/Alfred.alfredpreferences"
[ -d "$prefs_dir/workflows" ] || { echo "No workflows folder in $prefs_dir" >&2; exit 1; }

matches=()
for plist in "$prefs_dir"/workflows/*/info.plist; do
  if [ "$(/usr/libexec/PlistBuddy -c 'Print :bundleid' "$plist" 2>/dev/null || true)" = "$bundle_id" ]; then
    matches+=("$(dirname "$plist")")
  fi
done
case ${#matches[@]} in
  0) echo "$bundle_id is not installed in $prefs_dir; import kiosk-satellite.alfredworkflow once first." >&2; exit 1 ;;
  1) dest="${matches[0]}" ;;
  *) echo "Several workflows use $bundle_id:" >&2; printf '  %s\n' "${matches[@]}" >&2; exit 1 ;;
esac

old_version="$(/usr/libexec/PlistBuddy -c 'Print :version' "$dest/info.plist" 2>/dev/null || echo '?')"
echo "Workflow:  $bundle_id"
echo "Installed: $dest"
echo "Version:   $old_version -> $version"
chmod +x script_filter.sh open_url.sh set_token.sh
rsync -a --itemize-changes --exclude prefs.plist "${files[@]}" "$dest/"
echo "Done. prefs.plist left as is."
