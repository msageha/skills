# Deco BE85 Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://deco-api.msageha.net/api`
(`deco.msageha.net` without `-api` is the router's web UI).
Run requests sequentially — the server serializes them per router session.

Most examples use `curl -s … | jq` for brevity, which shows the body but not
whether the request succeeded (see the success check in SKILL.md). Send a write
with the body saved to a file and the status printed, using the operation's
method and body:

```bash
curl -sS -o "<body-file>" -w '%{http_code}\n' -X POST "<url>" -H "Content-Type: application/json" -d '<body>'
```

Go on only when curl exited 0 and the printed status is the one the operation
returns on success, then read the fields needed with `jq -e '<filter>' "<body-file>"`
(skip it for an operation that returns no body, such as `204`). Before reporting
the write as done, read the new state back with the matching read named in
SKILL.md.

The write examples below use `| jq` only to show the shape of the response;
send them in the form above, with their method, path and body. Free text taken from responses, web pages or other external sources
(names, descriptions, URLs) goes into the body through a file, not pasted into
the command: `jq -n --rawfile v "<text-file>" '($v | sub("\r?\n$"; "")) as $v | <filter>' > "<body-file>"`
builds the body (dropping the file's trailing LF or CRLF), and
`--data-binary @"<body-file>"` sends it. A value with quotes or backslashes
also breaks a JSON literal in `-d '…'`: build such a body with jq
(`--arg <name> '<value>'`) instead of pasting the value into the JSON.

## Health / Dashboard

```bash
curl -sf "https://deco-api.msageha.net/api/health" | jq .

# Login is lazy; force it (or drop the router session) explicitly
curl -sf -X POST "https://deco-api.msageha.net/api/login" | jq .
curl -sf -X POST "https://deco-api.msageha.net/api/logout" | jq .

curl -sf "https://deco-api.msageha.net/api/dashboard" | jq '{
  internet_online, wan_ipv4, connection_type,
  cpu_usage, mem_usage, deco_count, online_clients
}'
```

## Deco Units (Mesh Nodes)

```bash
curl -sf "https://deco-api.msageha.net/api/devices" | jq '.[] | {
  nickname, role, device_ip, mac, online, software_ver
}'
```

## Connected Clients

```bash
# Online clients only
curl -sf "https://deco-api.msageha.net/api/clients?online_only=true" | jq '.[] | {
  name, ip, mac, connection_type, down_speed, up_speed
}'

# Blocked clients
curl -sf "https://deco-api.msageha.net/api/clients/blocked" | jq '.[] | {name, mac}'
```

## Wi-Fi Status

```bash
# Enable state per band (host / guest)
curl -sf "https://deco-api.msageha.net/api/wireless" | jq 'to_entries
  | map(select(.key | startswith("band")))
  | map({band: .key, host: .value.host.enable, guest: .value.guest.enable})'

# SSIDs are base64-encoded — decode when displaying (select fields; never print .password)
curl -sf "https://deco-api.msageha.net/api/wireless" \
  | jq '.band5_1.host.ssid | @base64d'

# Radio details
curl -sf "https://deco-api.msageha.net/api/wireless/power" | jq .
curl -sf "https://deco-api.msageha.net/api/wireless/beamforming" | jq .
curl -sf "https://deco-api.msageha.net/api/wireless/operation-mode" | jq .
curl -sf "https://deco-api.msageha.net/api/wireless/bridge" | jq .
curl -sf "https://deco-api.msageha.net/api/wireless/roaming" | jq .
curl -sf "https://deco-api.msageha.net/api/wireless/bandwidth" | jq .
```

## Wi-Fi ON/OFF (band toggle)

Briefly disconnects clients on that band: read the current state with
`GET /wireless` and confirm with current → new first, naming the bands.

```bash
# Turn guest Wi-Fi OFF (2.4 + 5 GHz together; the separate 6 GHz guest is untouched)
curl -sf -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"network": "guest", "enable": false}' | jq .

# The 6 GHz guest is separate: enabling it ({"band": "band6", "network": "guest", "enable": true})
# broadcasts a guest SSID with no password (OWE) — confirm it with the user first.

# Turn 6 GHz host Wi-Fi OFF
curl -sf -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band6", "network": "host", "enable": false}' | jq .
```

## Wi-Fi Config (SSID / password / channel)

Briefly disconnects clients: read the band's current settings and confirm with
current → new first (for the password, only that it changes). `ssid` / `password` in plain text — the server base64-encodes them.
Only `updated` has the password masked, so print that rather than the whole
response. A new password doesn't go into the command: the user writes it to a
file outside the repository (`<password-file>`), jq reads it from there and
builds the body into a temporary file (a trailing LF or CRLF is dropped, and the
JSON stays valid whatever characters the values contain), and curl sends that
file only when jq succeeded. Check the status, then compare the stored
password with the file without printing either; afterwards ask the user to
delete `<password-file>`.

```bash
# Change the 5 GHz guest's SSID and password (mktemp files are readable only by you). Guest
# Wi-Fi is per band: to change every guest, repeat this and the read-back for each band
# whose guest isn't is_separate in /app/wireless/wlan/read
body=$(mktemp) && resp=$(mktemp) || exit 1; trap 'rm -f "$body" "$resp"' EXIT
jq -n --arg ssid '<ssid>' --rawfile pw "<password-file>" \
  '($pw | sub("\r?\n$"; "")) as $pw
   | if ($ssid == "" or $pw == "") then error("SSID or password is empty") else
     {band: "band5_1", network: "guest", settings: {ssid: $ssid, password: $pw}} end' \
  > "$body" || exit 1
code=$(curl -sS -o "$resp" -w '%{http_code}' -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" --data-binary @"$body") && [ "$code" = 200 ] \
  || { echo "failed (HTTP ${code:-none})"; jq '{error_code} // empty' "$resp" 2>/dev/null; exit 1; }
jq .updated "$resp"
# Read back: true / false only, neither password is printed
curl -sf "https://deco-api.msageha.net/api/wireless" \
  | jq -e --rawfile pw "<password-file>" '.band5_1.guest.password == ($pw | sub("\r?\n$"; "") | @base64)'

# Guest limits (guest only): no time limit, isolate guests from the main network
curl -sf -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest",
       "settings": {"access_duration": -1, "host_isolation": true}}' | jq .updated

# Fix the 5 GHz channel (radio setting — applies to the whole band)
curl -sf -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "settings": {"channel": 36}}' | jq .updated
```

## Network Status

```bash
curl -sf "https://deco-api.msageha.net/api/network/wan" | jq '.wan | {dial_type, ip: .ip_info.ip}'
curl -sf "https://deco-api.msageha.net/api/network/internet" | jq .
curl -sf "https://deco-api.msageha.net/api/network/lan" | jq .
curl -sf "https://deco-api.msageha.net/api/network/ipv6" | jq .
curl -sf "https://deco-api.msageha.net/api/network/performance" | jq .

# WAN details
curl -sf "https://deco-api.msageha.net/api/network/wan-mode" | jq .
curl -sf "https://deco-api.msageha.net/api/network/dhcp-dial" | jq .
curl -sf "https://deco-api.msageha.net/api/network/igmp" | jq .
curl -sf "https://deco-api.msageha.net/api/network/fast-xmit" | jq .
curl -sf "https://deco-api.msageha.net/api/network/vlan" | jq .
curl -sf "https://deco-api.msageha.net/api/network/ddns" | jq .
curl -sf "https://deco-api.msageha.net/api/network/mac-clone" | jq .
```

## Device / Cloud Info

```bash
curl -sf "https://deco-api.msageha.net/api/device/mode" | jq .
curl -sf "https://deco-api.msageha.net/api/device/time" | jq .
curl -sf "https://deco-api.msageha.net/api/device/speedtest" | jq .   # last result only (kbps), doesn't run a test
curl -sf "https://deco-api.msageha.net/api/cloud/device-info" | jq .
curl -sf "https://deco-api.msageha.net/api/cloud/login-status" | jq .
```

## System Log / Firmware

```bash
# Log categories (value = level below)
curl -sf "https://deco-api.msageha.net/api/system/log-types" | jq .

# First page of everything up to level 3 (ERROR), 50 entries
curl -sf "https://deco-api.msageha.net/api/system/log?level=3&index=0&limit=50" \
  | jq '{totalNum, currentIndex, lines: [.logList[].content]}'

# Firmware update check per node (asks TP-Link cloud; takes a few seconds)
curl -sf "https://deco-api.msageha.net/api/system/firmware" | jq '.[] | {
  device_model, software_ver, new_version, need_to_upgrade
}'

# Component info / UI switches
curl -sf "https://deco-api.msageha.net/api/system/component-info" | jq .
curl -sf "https://deco-api.msageha.net/api/system/switch-list" | jq .
```

## Speed Test

```bash
set -o pipefail
base=https://deco-api.msageha.net/api
before=$(curl -sf -m 10 "$base/device/speedtest" | jq -e '.last_speed_test_time | numbers // "none"') \
  || { echo "cannot read the last result"; exit 1; }
# A 4xx means it didn't start; after a 5xx or timeout it may have, so keep polling
curl -s -m 30 -o /dev/null -w '%{http_code}' -X POST "$base/luci/device/speedtest/write" \
  -H "Content-Type: application/json" -d '{}' | grep -q '^4' && { echo "start rejected"; exit 1; }
# About 1 min; give up after 5 min or on status "fail"
r=$(mktemp) || exit 1; trap 'rm -f "$r"' EXIT
deadline=$((SECONDS + 300))
while sleep 5; [ "$SECONDS" -lt "$deadline" ]; do
  curl -sf -m 10 -o "$r" "$base/device/speedtest" || continue
  [ "$(jq -r '.status' "$r")" = fail ] && { echo "speed test failed"; exit 1; }
  jq -e --argjson before "$before" '.status == "idle" and .ever_tested
      and (.last_speed_test_time | type == "number") and .last_speed_test_time != $before
      and (.down_speed | type == "number") and (.up_speed | type == "number")' "$r" >/dev/null \
    && { jq '{down_mbps: (.down_speed / 1000), up_mbps: (.up_speed / 1000)}' "$r"; exit 0; }
done
echo "no new result within 5 min (last response: $(cat "$r"))"; exit 1
```

## LEDs

```bash
curl -sf -X POST "https://deco-api.msageha.net/api/app/device/led/read" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Turn the LEDs off (confirm first unless the user asked for it)
curl -sf -X POST "https://deco-api.msageha.net/api/app/device/led/write" \
  -H "Content-Type: application/json" -d '{"params": {"enable": false}}' | jq .
```

## Firmware Upgrade (destructive — network down for minutes; confirm first)

Run each step separately and go on only when the previous one succeeded (or, for
step 2, may have started — step 3 then tells).

1. Check — don't skip it: the router reports download progress only after a
   check in the same router session. Stop unless some node has
   `need_to_upgrade: true` (`null` means unknown):

```bash
set -o pipefail
curl -sf "https://deco-api.msageha.net/api/system/firmware" | jq '.[] | {mac, device_model, software_ver, new_version, need_to_upgrade}'
```

2. Download. `200` with curl exit 0 means it started; a `4xx` means it didn't —
   stop. On anything else (a `5xx`, timeout, dropped connection `000`) it may
   have started: don't resend, and let step 3 tell:

```bash
code=$(curl -s -m 30 -o /dev/null -w '%{http_code}' -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware/download" \
  -H "Content-Type: application/json" -d '{}'); echo "curl exit $?, HTTP $code"   # 200 needs exit 0 too
```

3. Poll until the download completes. Check `status` before
   `download_progress`: 5 consecutive polls with `status` `fail`, `preparing`
   or missing mean it failed (their progress doesn't count). If step 2 didn't return `200`, this also
   tells whether the download started:

```bash
r=$(mktemp) || exit 1; trap 'rm -f "$r"' EXIT
deadline=$((SECONDS + 600)); misses=0
while sleep 3; [ "$SECONDS" -lt "$deadline" ]; do
  curl -sf -m 30 -o "$r" -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware_status/read" \
    -H "Content-Type: application/json" -d '{}' || { echo "read failed; download state unknown — don't resend step 2"; exit 1; }
  case "$(jq -r '.status' "$r")" in
    fail | preparing | null | "") misses=$((misses + 1)); [ "$misses" -ge 5 ] && { echo "download failed"; exit 1; }; continue ;;
  esac
  misses=0
  jq -c '{status, download_progress}' "$r"
  jq -e '.download_progress == 100' "$r" >/dev/null && { echo "downloaded"; exit 0; }
done
echo "not downloaded within 10 min"; exit 1
```

4. Upgrade (`upgrade_time` + `reboot_time` = expected downtime in seconds). A
   4xx means it didn't start. On a 5xx, timeout, dropped connection or
   unparsable response, the upgrade may have started — don't resend; wait
   several minutes and re-check each node's `software_ver` (by `mac`) with step 1:

```bash
curl -s -m 120 -w '\nHTTP %{http_code}\n' -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware_status/upgrade" \
  -H "Content-Type: application/json" -d '{"confirm": true}'
```

## Other Router Operations (`/luci/...`, `/app/...`)

A call the user didn't ask for runs without asking only when the list below
shows `x-deco-read-only` as `true` (the reads in this section are); a name such
as `read` or `get` doesn't prove the call has no side effects. Calls the user
asked for follow the confirmation rules in SKILL.md. Responses can include passwords and keys (sometimes base64) — print only the
fields needed.

```bash
# List operations (path, read-only flag, destructive flag); replace <keyword>, e.g. speedtest
curl -s "https://deco-api.msageha.net/openapi.json" | jq -r '.paths | to_entries[]
  | select(.key | test("^/api/(luci|app)/")) | select(.key | test("<keyword>"))
  | "\(.key)\t\(.value.post["x-deco-read-only"])\t\(.value.post["x-deco-destructive"])"'

# DHCP reservations
curl -sf -X POST "https://deco-api.msageha.net/api/luci/client/addr_reservation/getlist" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Port forwarding rules
curl -sf -X POST "https://deco-api.msageha.net/api/app/nat/vs/getlist" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Guest-only Wi-Fi details (response also holds passwords — show only these fields)
curl -sf -X POST "https://deco-api.msageha.net/api/app/wireless/wlan/read" \
  -H "Content-Type: application/json" -d '{}' \
  | jq 'with_entries(select((.key | startswith("band")) and (.value.guest | type == "object")))
        | map_values(.guest | {enable, is_separate, encryption_mode, host_isolation, access_duration, bandwidth_limit})'
```

## Reboot (destructive — confirm with the user first)

```bash
# All Deco units
curl -sf -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}' | jq .

# Specific units (MACs from GET /devices) — drops their clients and the mesh links
# behind them. An empty or null "macs" reboots every unit, so stop if the lookup
# found nothing
curl -sf -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true, "macs": ["<mac>"]}' | jq .
```

## Raw Passthrough (advanced)

A path + operation pair that backs a typed `GET` endpoint (listed in
api-reference; for `feedback_log`, only `read`) is safe; for any other call, confirm first — even a `read` can
have side effects. `/raw` reaches any form, including ones that return credentials — print only
the fields needed.

```bash
curl -sf -X POST "https://deco-api.msageha.net/api/raw" \
  -H "Content-Type: application/json" \
  -d '{"path": "admin/client?form=client_list", "operation": "read",
       "params": {"device_mac": "default"}}' \
  | jq 'if .success == false or ((.error_code // 0) != 0) then {success, error_code}
        else (.result // .data).client_list | map({name: (.name // "" | @base64d), ip, mac}) end'
```

A router-side error comes back as HTTP 200 with `success: false` or a
non-zero `error_code` in the envelope. `/raw` returns names base64-encoded
(the typed `GET /clients` decodes them).
