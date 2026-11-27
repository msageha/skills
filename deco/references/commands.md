# Deco BE85 Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://deco-api.msageha.net/api`
(`deco.msageha.net` without `-api` is the router's web UI).
Run requests sequentially — the server serializes them per router session.

The examples use `curl -s` for brevity, which exits 0 on an HTTP error, and pipe
to `jq`, which turns an error body into `null`s. Before reporting a write as
done or trusting a filtered result, check the request: run with
`set -o pipefail` and `curl -sf`, or save the body with `-o <file>` and read
the status from `-w '%{http_code}'`.

## Health / Dashboard

```bash
curl -s "https://deco-api.msageha.net/api/health" | jq .

# Login is lazy; force it (or drop the router session) explicitly
curl -s -X POST "https://deco-api.msageha.net/api/login" | jq .
curl -s -X POST "https://deco-api.msageha.net/api/logout" | jq .

curl -s "https://deco-api.msageha.net/api/dashboard" | jq '{
  internet_online, wan_ipv4, connection_type,
  cpu_usage, mem_usage, deco_count, online_clients
}'
```

## Deco Units (Mesh Nodes)

```bash
curl -s "https://deco-api.msageha.net/api/devices" | jq '.[] | {
  nickname, role, device_ip, mac, online, software_ver
}'
```

## Connected Clients

```bash
# Online clients only
curl -s "https://deco-api.msageha.net/api/clients?online_only=true" | jq '.[] | {
  name, ip, mac, connection_type, down_speed, up_speed
}'

# Blocked clients
curl -s "https://deco-api.msageha.net/api/clients/blocked" | jq '.[] | {name, mac}'
```

## Wi-Fi Status

```bash
# Enable state per band (host / guest)
curl -s "https://deco-api.msageha.net/api/wireless" | jq 'to_entries
  | map(select(.key | startswith("band")))
  | map({band: .key, host: .value.host.enable, guest: .value.guest.enable})'

# SSIDs are base64-encoded — decode when displaying (leave .password encoded unless asked)
curl -s "https://deco-api.msageha.net/api/wireless" \
  | jq '.band5_1.host.ssid | @base64d'

# Radio details
curl -s "https://deco-api.msageha.net/api/wireless/power" | jq .
curl -s "https://deco-api.msageha.net/api/wireless/beamforming" | jq .
curl -s "https://deco-api.msageha.net/api/wireless/operation-mode" | jq .
curl -s "https://deco-api.msageha.net/api/wireless/bridge" | jq .
curl -s "https://deco-api.msageha.net/api/wireless/roaming" | jq .
curl -s "https://deco-api.msageha.net/api/wireless/bandwidth" | jq .
```

## Wi-Fi ON/OFF (band toggle)

Briefly disconnects clients on that band — confirm with the user first.

```bash
# Turn guest Wi-Fi OFF (2.4 + 5 GHz together; the separate 6 GHz guest is untouched)
curl -s -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"network": "guest", "enable": false}' | jq .

# The 6 GHz guest is separate: enabling it ({"band": "band6", "network": "guest"})
# can broadcast a guest SSID with no password (OWE) — warn the user first.

# Turn 6 GHz host Wi-Fi OFF
curl -s -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band6", "network": "host", "enable": false}' | jq .
```

## Wi-Fi Config (SSID / password / channel)

Briefly disconnects clients — confirm with the user first. `ssid` / `password`
in plain text — the server base64-encodes them. Only `updated` has the
password masked, so print that rather than the whole response.

```bash
# Change guest Wi-Fi SSID and password. jq builds the JSON from the environment,
# so it stays valid whatever characters the values contain (single-quote them
# for the shell; write a ' inside as '\'').
export SSID='<ssid>' WIFI_PASSWORD='<password>'
[ -n "$SSID" ] && [ -n "$WIFI_PASSWORD" ] || { echo "SSID or password is empty"; exit 1; }
jq -n '{band: "band5_1", network: "guest", settings: {ssid: env.SSID, password: env.WIFI_PASSWORD}}' \
  | curl -s -X POST "https://deco-api.msageha.net/api/wireless/config" \
      -H "Content-Type: application/json" --data @- | jq .updated

# Guest limits (guest only): no time limit, isolate guests from the main network
curl -s -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest",
       "settings": {"access_duration": -1, "host_isolation": true}}' | jq .updated

# Fix the 5 GHz channel (radio setting — applies to the whole band)
curl -s -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "settings": {"channel": 36}}' | jq .updated
```

## Network Status

```bash
curl -s "https://deco-api.msageha.net/api/network/wan" | jq '.wan | {dial_type, ip: .ip_info.ip}'
curl -s "https://deco-api.msageha.net/api/network/internet" | jq .
curl -s "https://deco-api.msageha.net/api/network/lan" | jq .
curl -s "https://deco-api.msageha.net/api/network/ipv6" | jq .
curl -s "https://deco-api.msageha.net/api/network/performance" | jq .

# WAN details
curl -s "https://deco-api.msageha.net/api/network/wan-mode" | jq .
curl -s "https://deco-api.msageha.net/api/network/dhcp-dial" | jq .
curl -s "https://deco-api.msageha.net/api/network/igmp" | jq .
curl -s "https://deco-api.msageha.net/api/network/fast-xmit" | jq .
curl -s "https://deco-api.msageha.net/api/network/vlan" | jq .
curl -s "https://deco-api.msageha.net/api/network/ddns" | jq .
curl -s "https://deco-api.msageha.net/api/network/mac-clone" | jq .
```

## Device / Cloud Info

```bash
curl -s "https://deco-api.msageha.net/api/device/mode" | jq .
curl -s "https://deco-api.msageha.net/api/device/time" | jq .
curl -s "https://deco-api.msageha.net/api/device/speedtest" | jq .   # last result only (kbps), doesn't run a test
curl -s "https://deco-api.msageha.net/api/cloud/device-info" | jq .
curl -s "https://deco-api.msageha.net/api/cloud/login-status" | jq .
```

## System Log / Firmware

```bash
# Log categories (value = level below)
curl -s "https://deco-api.msageha.net/api/system/log-types" | jq .

# First page of everything up to level 3 (ERROR), 50 entries
curl -s "https://deco-api.msageha.net/api/system/log?level=3&index=0&limit=50" \
  | jq '{totalNum, currentIndex, lines: [.logList[].content]}'

# Firmware update check per node (asks TP-Link cloud; takes a few seconds)
curl -s "https://deco-api.msageha.net/api/system/firmware" | jq '.[] | {
  device_model, software_ver, new_version, need_to_upgrade
}'

# Component info / UI switches
curl -s "https://deco-api.msageha.net/api/system/component-info" | jq .
curl -s "https://deco-api.msageha.net/api/system/switch-list" | jq .
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
deadline=$((SECONDS + 300))
while sleep 5; [ "$SECONDS" -lt "$deadline" ]; do
  r=$(curl -sf -m 10 "$base/device/speedtest") || continue
  [ "$(jq -r '.status' <<<"$r")" = fail ] && { echo "speed test failed"; exit 1; }
  jq -e --argjson before "$before" '.status == "idle" and .ever_tested
      and (.last_speed_test_time | type == "number") and .last_speed_test_time != $before
      and (.down_speed | type == "number") and (.up_speed | type == "number")' <<<"$r" >/dev/null \
    && { jq '{down_mbps: (.down_speed / 1000), up_mbps: (.up_speed / 1000)}' <<<"$r"; exit 0; }
done
echo "no new result within 5 min (last response: ${r:-none})"; exit 1
```

## LEDs

```bash
curl -s -X POST "https://deco-api.msageha.net/api/app/device/led/read" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Turn the LEDs off (confirm with the user first)
curl -s -X POST "https://deco-api.msageha.net/api/app/device/led/write" \
  -H "Content-Type: application/json" -d '{"params": {"enable": false}}' | jq .
```

## Firmware Upgrade (destructive — network down for minutes; confirm first)

Run each step separately and go on only when the previous one succeeded.

1. Check — don't skip it: the router reports download progress only after a
   check in the same router session. Stop unless some node has
   `need_to_upgrade: true` (`null` means unknown):

```bash
set -o pipefail
curl -sf "https://deco-api.msageha.net/api/system/firmware" | jq '.[] | {mac, device_model, software_ver, new_version, need_to_upgrade}'
```

2. Download (stop on a non-zero exit):

```bash
curl -sf -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware/download" \
  -H "Content-Type: application/json" -d '{}'
```

3. Poll until the download completes. Check `status` before
   `download_progress`: 5 consecutive polls with `status` `fail`, `preparing`
   or missing mean it failed (their progress doesn't count). If step 2 lost its response, this also
   tells whether the download started:

```bash
deadline=$((SECONDS + 600)); misses=0
while sleep 3; [ "$SECONDS" -lt "$deadline" ]; do
  r=$(curl -sf -m 30 -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware_status/read" \
    -H "Content-Type: application/json" -d '{}') || { echo "read failed"; exit 1; }
  case "$(jq -r '.status' <<<"$r")" in
    fail | preparing | null | "") misses=$((misses + 1)); [ "$misses" -ge 5 ] && { echo "download failed"; exit 1; }; continue ;;
  esac
  misses=0
  jq -c '{status, download_progress}' <<<"$r"
  jq -e '.download_progress == 100' <<<"$r" >/dev/null && { echo "downloaded"; exit 0; }
done
echo "not downloaded within 10 min"; exit 1
```

4. Upgrade (`upgrade_time` + `reboot_time` = expected downtime in seconds). A
   4xx means it didn't start. On a 5xx, timeout, dropped connection or
   unparsable response, the upgrade may have started — don't resend; wait
   several minutes and re-check each node's `software_ver` (by `mac`) with step 1:

```bash
curl -s -w '\nHTTP %{http_code}\n' -X POST "https://deco-api.msageha.net/api/luci/cloud/firmware_status/upgrade" \
  -H "Content-Type: application/json" -d '{"confirm": true}'
```

## Other Router Operations (`/api/luci/...`, `/api/app/...`)

Read-like operations are safe; others change settings — confirm first.
Responses can include passwords and keys (sometimes base64) — print only the
fields needed.

```bash
# List operations (path, destructive flag); replace <keyword>, e.g. speedtest
curl -s "https://deco-api.msageha.net/openapi.json" | jq -r '.paths | to_entries[]
  | select(.key | test("^/api/(luci|app)/")) | select(.key | test("<keyword>"))
  | "\(.key)\t\(.value.post["x-deco-destructive"])"'

# DHCP reservations
curl -s -X POST "https://deco-api.msageha.net/api/luci/client/addr_reservation/getlist" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Port forwarding rules
curl -s -X POST "https://deco-api.msageha.net/api/app/nat/vs/getlist" \
  -H "Content-Type: application/json" -d '{}' | jq .

# Guest-only Wi-Fi details (response also holds passwords — show only these fields)
curl -s -X POST "https://deco-api.msageha.net/api/app/wireless/wlan/read" \
  -H "Content-Type: application/json" -d '{}' \
  | jq 'with_entries(select((.key | startswith("band")) and (.value.guest | type == "object")))
        | map_values(.guest | {enable, is_separate, encryption_mode, host_isolation, access_duration, bandwidth_limit})'
```

## Reboot (destructive — confirm with the user first)

```bash
# All Deco units
curl -s -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}' | jq .

# Specific units (MACs from GET /devices) — drops their clients and the mesh links
# behind them. An empty or null "macs" reboots every unit, so stop if the lookup
# found nothing
curl -s -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true, "macs": ["AA-BB-CC-DD-EE-FF"]}' | jq .
```

## Raw Passthrough (advanced)

Read is safe; non-`read` operations change router settings — confirm first.
`/raw` reaches any form, including ones that return credentials — print only
the fields needed.

```bash
curl -s -X POST "https://deco-api.msageha.net/api/raw" \
  -H "Content-Type: application/json" \
  -d '{"path": "admin/client?form=client_list", "operation": "read",
       "params": {"device_mac": "default"}}' \
  | jq 'if .success == false or ((.error_code // 0) != 0) then . else .result.client_list | map({name: (.name | @base64d), ip, mac}) end'
```

A router-side error comes back as HTTP 200 with `success: false` or a
non-zero `error_code` in the envelope. `/raw` returns names base64-encoded
(the typed `GET /clients` decodes them).
