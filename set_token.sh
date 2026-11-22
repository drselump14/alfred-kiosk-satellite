#!/bin/bash
# Run Script action behind `kadm:token` and `kadm:url`: save a value to the
# login Keychain (generic password, service com.drselump14.kiosk_satellite_admin)
# so it survives re-importing the workflow, which resets Alfred's saved settings.
#
# Input comes from workflow variables set by the Arg and Vars objects, not argv:
#   ks_account  ha_token or ha_url
#   ks_value    the token, an op:// reference, or the HA base URL
#
# The value is handed to `security` on stdin (its -i command mode) rather than as
# `-w <value>` on the command line, so it never appears in `ps` output.
#
# Testing: KS_KEYCHAIN_SERVICE overrides the Keychain service name.
service="${KS_KEYCHAIN_SERVICE:-com.drselump14.kiosk_satellite_admin}"
account="${ks_account:-}"
value="${ks_value:-}"

case "$account" in
  ha_token|ha_url) ;;
  *) echo "Unknown setting: ${account:-none}"; exit 1 ;;
esac

# Alfred may pass a trailing newline; strip surrounding whitespace.
value="${value#"${value%%[![:space:]]*}"}"
value="${value%"${value##*[![:space:]]}"}"
if [ -z "$value" ]; then
  echo "Nothing to save for $account"
  exit 1
fi
case "$value" in
  *$'\n'*|*$'\r'*) echo "Value for $account must be a single line"; exit 1 ;;
esac
[ "$account" = "ha_url" ] && value="${value%/}"

# security -i reads double-quoted words with backslash escapes.
quote() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }

if printf 'add-generic-password -U -s %s -a %s -l %s -w %s\n' \
     "$(quote "$service")" "$(quote "$account")" "$(quote "Kiosk Satellite Admin ($account)")" \
     "$(quote "$value")" | /usr/bin/security -i >/dev/null 2>&1 \
   && [ "$(/usr/bin/security find-generic-password -s "$service" -a "$account" -w 2>/dev/null)" = "$value" ]; then
  case "$account" in
    ha_token) case "$value" in op://*) echo "1Password reference saved to Keychain" ;; *) echo "Token saved to Keychain" ;; esac ;;
    ha_url) echo "Home Assistant URL saved: $value" ;;
  esac
else
  echo "Could not save $account to Keychain"
  exit 1
fi
