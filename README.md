# Kiosk Satellite Admin

Alfred 5 workflow: pick one of the Kiosk Satellite tablets known to Home
Assistant and open its admin web page in Firefox.

```
kadm                      list every satellite
kadm kitchen              filter by name, host, area or model
kadm:token <token|op://…> save the HA token (or a 1Password reference) to the Keychain
kadm:url <url>            save the HA base URL to the Keychain
```

- **Enter**: open the admin URL in the browser (`open -a Firefox <url>`)
- **Cmd+Enter**: open the device's page in Home Assistant
- **Alt+Enter**: copy the admin URL

## Where the list comes from

A small Home Assistant package, [`homeassistant/kiosk_satellites.yaml`](homeassistant/kiosk_satellites.yaml),
builds the list inside HA as `sensor.kiosk_satellites` (state = count,
attribute `satellites` = the list). Its template walks every ESPHome-integration
device and keeps the ones that look like Kiosk Satellite tablets:
model/manufacturer contains "kiosk", or the device owns a `*_hold_mode`,
`*_dashboard_view` or `*_screensaver_active` entity, or an entity id contains
`kiosk_satellite`. It refreshes at startup, on template reload, when the device
registry changes, and every 5 minutes.

The Script Filter only reads that sensor (`GET /api/states/sensor.kiosk_satellites`),
so a token from a **non-admin** HA user is enough.

To see what HA found, open Developer Tools → States and look at
`sensor.kiosk_satellites`, or paste the template from the package into
Developer Tools → Template.

The host shown and used in the URL comes from, in order:

1. `host_overrides` (matched against the device name),
2. a sensor on the device whose state is an IPv4 address,
3. the host part of the device's `configuration_url`.

HA's REST API does not expose the ESPHome config entry's `host`, so if your
tablets have neither an IP sensor nor a configuration URL, fill
`host_overrides`. Devices without a host stay in the list but can't be opened.

## Setup

1. Copy `homeassistant/kiosk_satellites.yaml` to `/config/packages/` on your HA
   (needs `homeassistant: packages: !include_dir_named packages` in
   `configuration.yaml`) and restart HA, or reload Template entities.
2. Optional but recommended: create a non-admin HA user (local network only) and
   make a long-lived token for it (Profile → Security).

Requires `jq` (`brew install jq`) and, for the 1Password option, the `op` CLI.

Double-click `kiosk-satellite.alfredworkflow`, then save the token:

```
kadm:token op://Private/Home Assistant/credential   # or paste the token itself
kadm:url https://192.0.2.20:8123                    # optional
```

Both are stored in your login Keychain as generic passwords (service
`com.drselump14.kiosk_satellite_admin`, accounts `ha_token` and `ha_url`), so
they survive re-importing the workflow. Re-importing with **Replace** resets
everything saved in **Configure Workflow**.

The token is looked up in this order; the first one found wins:

1. `ha_token` (Configure Workflow),
2. `ha_token_ref` (Configure Workflow), read with `op read`,
3. Keychain account `ha_token`; a value starting with `op://` is read with `op read`.

`ha_url` works the same way: the Configure Workflow value, then Keychain account
`ha_url`, then `http://homeassistant.local:8123`. If no token is found, the list
shows "Token not set — run kadm:token".

`kadm:token` hands the value to `security` on stdin (`security -i`), not as a
`-w <value>` argument, so it never appears in `ps`. It does pass through an
Alfred workflow variable, so it can show up in Alfred's workflow debugger while
that is open. To change or remove the item by hand use Keychain Access, or
`security delete-generic-password -s com.drselump14.kiosk_satellite_admin -a ha_token`.

Everything in **Configure Workflow** is optional apart from the keyword:

| Variable | Default | Notes |
|---|---|---|
| `keyword` | `kadm` | |
| `ha_url` | | Your HA base URL, e.g. `https://192.0.2.20:8123`. Empty: Keychain (`kadm:url`), then `http://homeassistant.local:8123`. |
| `ha_token` | | Long-lived token (HA → Profile → Security). Wins over everything else. Lost on re-import; prefer `kadm:token`. |
| `ha_token_ref` | | 1Password reference, read with `op read` on each run. Used when `ha_token` is empty. Lost on re-import. |
| `ha_verify_ssl` | off | Only matters for an `https://` URL. Leave off for a self-signed cert; turn on for a publicly trusted one. |
| `admin_url_template` | `http://{host}:2324/` | `{host}` is replaced. |
| `host_overrides` | | `name=host` per line or comma separated, e.g. `Kitchen Kiosk Satellite=192.0.2.10`. Also used as a static list if HA can't be reached. |
| `browser` | `Firefox` | Any app name `open -a` accepts |

Alfred keeps these values in the installed workflow's `prefs.plist`, so they
are not included when the workflow is exported, and a re-import resets them.

Results are cached by Alfred for 2 minutes, so `op read` (and its Touch ID
prompt) doesn't run on every keystroke.

## Development

```sh
# Run the Script Filter against HA
ha_token_ref='op://…' ./script_filter.sh | jq

# Or against a canned list
# (a JSON array shaped like the sensor's `satellites` attribute)
KS_MOCK_JSON=/path/to/devices.json ./script_filter.sh | jq

# Use a throwaway Keychain item instead of the real one
KS_KEYCHAIN_SERVICE=test.kiosk ks_account=ha_token ks_value=dummy ./set_token.sh
KS_KEYCHAIN_SERVICE=test.kiosk ./script_filter.sh | jq
security delete-generic-password -s test.kiosk -a ha_token

# Update the installed workflow in place (no re-import, keeps prefs.plist)
./install.sh

# Rebuild the package
zip -j kiosk-satellite.alfredworkflow info.plist icon.png script_filter.sh open_url.sh set_token.sh
```

`install.sh` reads the Alfred preferences folder from
`~/Library/Application Support/Alfred/prefs.json` (`.current`), finds the
installed workflow by bundle id, and rsyncs `info.plist`, `icon.png` and the
scripts into it with `--exclude prefs.plist`. Only the first install needs the
`.alfredworkflow` package.
