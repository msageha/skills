# Deco BE85 Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://deco-api.msageha.net/api`
(`deco.msageha.net` without `-api` is the router's web UI).
Run requests sequentially — the server serializes them behind one router session.

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
# Turn guest Wi-Fi (5 GHz) ON
curl -s -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest", "enable": true}' | jq .

# Turn 6 GHz host Wi-Fi OFF
curl -s -X POST "https://deco-api.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band6", "network": "host", "enable": false}' | jq .
```

## Wi-Fi Config (SSID / password / channel)

`ssid` / `password` in plain text — the server base64-encodes them.

```bash
# Change guest Wi-Fi SSID and password
curl -s -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest",
       "settings": {"enable": true, "ssid": "My Guest", "password": "secretpass"}}' | jq .

# Fix the 5 GHz channel
curl -s -X POST "https://deco-api.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "settings": {"channel": 36}}' | jq .
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
curl -s "https://deco-api.msageha.net/api/device/speedtest" | jq .   # last result only, doesn't run a test
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

## Reboot (destructive — confirm with the user first)

```bash
# All Deco units
curl -s -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}' | jq .

# A specific unit (MAC from GET /devices)
curl -s -X POST "https://deco-api.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true, "macs": ["AA-BB-CC-DD-EE-FF"]}' | jq .
```

## Raw Passthrough (advanced)

Read is safe; non-`read` operations change router settings — confirm first.

```bash
curl -s -X POST "https://deco-api.msageha.net/api/raw" \
  -H "Content-Type: application/json" \
  -d '{"path": "admin/client?form=client_list", "operation": "read",
       "params": {"device_mac": "default"}}' | jq .
```
