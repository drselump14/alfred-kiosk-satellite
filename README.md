# Kiosk Satellite Admin

Alfred 5 workflow: pick one of the Kiosk Satellite tablets known to Home
Assistant and open its admin web page in Firefox.

```
kadm          list every satellite
kadm kitchen  filter by name, host, area or model
```

- **Enter**: open the admin URL in the browser (`open -a Firefox <url>`)
- **Cmd+Enter**: open the device's page in Home Assistant
- **Alt+Enter**: copy the admin URL

## Where the list comes from

The Script Filter POSTs `satellites.jinja` to Home Assistant's
`/api/template` endpoint. The template walks every ESPHome-integration device
and keeps the ones that look like Kiosk Satellite tablets: model/manufacturer
contains "kiosk", or the device owns a `*_hold_mode`, `*_dashboard_view` or
`*_screensaver_active` entity, or an entity id contains `kiosk_satellite`.

The host shown and used in the URL comes from, in order:

1. `host_overrides` (matched against the device name),
2. a sensor on the device whose state is an IPv4 address,
3. the host part of the device's `configuration_url`.

HA's REST API does not expose the ESPHome config entry's `host`, so if your
tablets have neither an IP sensor nor a configuration URL, fill
`host_overrides`. Devices without a host stay in the list but can't be opened.

## Setup

Requires `jq` (`brew install jq`) and, for the 1Password option, the `op` CLI.

Double-click `kiosk-satellite.alfredworkflow`, then fill in **Configure
Workflow**:

| Variable | Default | Notes |
|---|---|---|
| `keyword` | `kadm` | |
| `ha_url` | `http://homeassistant.local:8123` | Your HA base URL, e.g. `https://192.0.2.20:8123`. |
| `ha_token_ref` | | 1Password reference, read with `op read` on each run. Preferred over a plain token. |
| `ha_token` | | Long-lived token (HA → Profile → Security). Only used when `ha_token_ref` is empty. |
| `ha_verify_ssl` | off | Only matters for an `https://` URL. Leave off for a self-signed cert; turn on for a publicly trusted one. |
| `admin_url_template` | `http://{host}:2324/` | `{host}` is replaced. |
| `host_overrides` | | `name=host` per line or comma separated, e.g. `Kitchen Kiosk Satellite=192.0.2.10`. Also used as a static list if HA can't be reached. |
| `browser` | `Firefox` | Any app name `open -a` accepts |

Alfred keeps these values in its own preferences, so they are not included
when the workflow is exported.

Results are cached by Alfred for 2 minutes, so `op read` (and its Touch ID
prompt) doesn't run on every keystroke.

## Development

```sh
# Run the Script Filter against HA
ha_token_ref='op://…' ./script_filter.sh | jq

# Or against canned template output
# (a JSON array shaped like the template's output)
KS_MOCK_JSON=/path/to/devices.json ./script_filter.sh | jq

# Rebuild the package
zip -j kiosk-satellite.alfredworkflow info.plist icon.png script_filter.sh open_url.sh satellites.jinja
```
