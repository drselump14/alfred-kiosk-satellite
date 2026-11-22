#!/bin/bash
# Alfred Script Filter: list Kiosk Satellite tablets known to Home Assistant.
#
# Workflow variables (Alfred user configuration, or plain env when run by hand):
#   ha_url              Home Assistant base URL (default http://homeassistant.local:8123)
#   ha_token            Long-lived access token (optional if ha_token_ref is set)
#   ha_token_ref        1Password reference, e.g. op://Private/<item>/credential,
#                       resolved with `op read` at runtime when ha_token is empty
#   ha_verify_ssl       1 to verify HA's TLS cert when ha_url is https
#                       (default 0, for self-signed LAN certs; no effect on http)
#   admin_url_template  URL opened for a satellite; {host} is replaced
#                       (default http://{host}:2324/)
#   host_overrides      Optional "name=host" pairs, comma or newline separated.
#                       Matched case-insensitively against the device name.
#                       Also used as a static list when HA is unreachable.
#
# Testing: KS_MOCK_JSON=<file> skips HA and reads the template output from a file.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ha_url="${ha_url:-http://homeassistant.local:8123}"
ha_url="${ha_url%/}"
default_template='http://{host}:2324/'
admin_url_template="${admin_url_template:-$default_template}"
host_overrides="${host_overrides:-}"

error_item() { # title subtitle
  jq -n --arg t "$1" --arg s "$2" '{items: [{title: $t, subtitle: $s, valid: false}]}'
}

if ! command -v jq >/dev/null 2>&1; then
  printf '{"items":[{"title":"jq not found","subtitle":"brew install jq","valid":false}]}'
  exit 0
fi

fetch_from_ha() {
  local token="${ha_token:-}"
  if [ -z "$token" ] && [ -n "${ha_token_ref:-}" ]; then
    token="$(op read "$ha_token_ref" 2>/dev/null)" || token=""
    [ -z "$token" ] && { echo "op read failed for ha_token_ref" >&2; return 2; }
  fi
  [ -z "$token" ] && return 3

  local curl_tls=(-k)
  [ "${ha_verify_ssl:-0}" = "1" ] && curl_tls=()
  # Token goes to curl via a config on stdin, so it never shows up in `ps`.
  jq -n --rawfile t "$HERE/satellites.jinja" '{template: $t}' |
    curl -sS --fail -m 8 "${curl_tls[@]}" -X POST "$ha_url/api/template" \
      -H "Content-Type: application/json" --data-binary @- \
      -K <(printf 'header = "Authorization: Bearer %s"\n' "$token")
}

if [ -n "${KS_MOCK_JSON:-}" ]; then
  raw="$(cat "$KS_MOCK_JSON")"; rc=$?
else
  raw="$(fetch_from_ha 2>"${TMPDIR:-/tmp}/alfred-kiosk-satellite.err")"; rc=$?
fi

if [ $rc -ne 0 ] || ! jq -e 'type == "array"' >/dev/null 2>&1 <<<"$raw"; then
  if [ -n "$host_overrides" ]; then
    raw='[]' # fall back to the static list below
  elif [ $rc -eq 3 ]; then
    error_item "Home Assistant token not set" "Set ha_token or ha_token_ref in the workflow's Configure Workflow panel"
    exit 0
  else
    error_item "Could not query Home Assistant" "$ha_url (exit $rc) — check ha_url / token, or set host_overrides"
    exit 0
  fi
fi

jq -c \
  --arg tmpl "$admin_url_template" \
  --arg overrides "$host_overrides" \
  --arg ha_url "$ha_url" '
  # "name=host" pairs -> {lowercased name: host}
  ($overrides | split("[,\n]"; null) | map(gsub("^\\s+|\\s+$"; "")) | map(select(contains("=")))
     | map(split("=") | {name: (.[0] | gsub("\\s+$"; "")), host: (.[1:] | join("=") | gsub("^\\s+"; ""))})) as $ovlist
  | ($ovlist | map({key: (.name | ascii_downcase), value: .host}) | from_entries) as $ov
  | . as $devs
  # Static entries for override names that HA did not return.
  | ($devs | map(.name | ascii_downcase)) as $known
  | ($devs + ($ovlist | map(select((.name | ascii_downcase) as $k | $known | index($k) | not))
       | map({name: .name, device_id: "", model: "", area: "", ip: "", configuration_url: ""})))
  | map(
      . as $d
      | ($ov[$d.name | ascii_downcase]
         // (if ($d.ip // "") != "" then $d.ip else null end)
         // (($d.configuration_url // "") | capture("^[a-z]+://(?<h>[^/:]+)").h? )
         // "") as $host
      | ($tmpl | gsub("\\{host\\}"; $host)) as $url
      | {
          uid: (if $d.device_id != "" then $d.device_id else $d.name end),
          title: $d.name,
          subtitle: (if $host == "" then "Host unknown — add it to host_overrides"
                     else ([$host, $d.area, $d.model] | map(select(. != "")) | join("  ·  ")) end),
          arg: $url,
          valid: ($host != ""),
          match: ([$d.name, $host, $d.area, $d.model] | join(" ")),
          autocomplete: $d.name,
          text: {copy: $url, largetype: $url},
          quicklookurl: $url,
          mods: {
            cmd: (if $d.device_id != "" then
                    {valid: true, arg: "\($ha_url)/config/devices/device/\($d.device_id)", subtitle: "Open device page in Home Assistant"}
                  else {valid: false, subtitle: "Not known to Home Assistant"} end),
            alt: {valid: ($host != ""), arg: $url, subtitle: "Copy admin URL: \($url)", variables: {action: "copy"}}
          }
        })
  | if length == 0 then
      {items: [{title: "No Kiosk Satellites found", subtitle: "No matching ESPHome devices in Home Assistant", valid: false}]}
    else {cache: {seconds: 120, loosereload: true}, items: .} end
' <<<"$raw"
