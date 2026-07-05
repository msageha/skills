# Deco BE85 Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://daikin.msageha.net/api`.
Run requests sequentially — the server serializes them behind one router session.

## Health / Dashboard

```bash
curl -s "https://daikin.msageha.net/api/health" | jq .

curl -s "https://daikin.msageha.net/api/dashboard" | jq '{
  internet_online, wan_ipv4, connection_type,
  cpu_usage, mem_usage, deco_count, online_clients
}'
```

## Deco Units (Mesh Nodes)

```bash
curl -s "https://daikin.msageha.net/api/devices" | jq '.[] | {
  nickname, role, device_ip, mac, online, software_ver
}'
```

## Connected Clients

```bash
# Online clients only
curl -s "https://daikin.msageha.net/api/clients?online_only=true" | jq '.[] | {
  name, ip, mac, connection_type, down_speed, up_speed
}'

# Blocked clients
curl -s "https://daikin.msageha.net/api/clients/blocked" | jq '.[] | {name, mac}'
```

## Wi-Fi Status

```bash
# Enable state per band (host / guest)
curl -s "https://daikin.msageha.net/api/wireless" | jq 'to_entries
  | map(select(.key | startswith("band")))
  | map({band: .key, host: .value.host.enable, guest: .value.guest.enable})'

# SSIDs are base64-encoded — decode when displaying
curl -s "https://daikin.msageha.net/api/wireless" \
  | jq '.band5_1.host.ssid | @base64d'
```

## Wi-Fi ON/OFF (band toggle)

Briefly disconnects clients on that band — confirm with the user first.

```bash
# Turn guest Wi-Fi (5 GHz) ON
curl -s -X POST "https://daikin.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest", "enable": true}' | jq .

# Turn 6 GHz host Wi-Fi OFF
curl -s -X POST "https://daikin.msageha.net/api/wireless" \
  -H "Content-Type: application/json" \
  -d '{"band": "band6", "network": "host", "enable": false}' | jq .
```

## Wi-Fi Config (SSID / password / channel)

`ssid` / `password` in plain text — the server base64-encodes them.

```bash
# Change guest Wi-Fi SSID and password
curl -s -X POST "https://daikin.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "network": "guest",
       "settings": {"enable": true, "ssid": "My Guest", "password": "secretpass"}}' | jq .

# Fix the 5 GHz channel
curl -s -X POST "https://daikin.msageha.net/api/wireless/config" \
  -H "Content-Type: application/json" \
  -d '{"band": "band5_1", "settings": {"channel": 36}}' | jq .
```

## Network Status

```bash
curl -s "https://daikin.msageha.net/api/network/wan" | jq '.wan | {dial_type, ip: .ip_info.ip}'
curl -s "https://daikin.msageha.net/api/network/internet" | jq .
curl -s "https://daikin.msageha.net/api/network/lan" | jq .
curl -s "https://daikin.msageha.net/api/network/ipv6" | jq .
curl -s "https://daikin.msageha.net/api/network/performance" | jq .
```

## Device Info

```bash
curl -s "https://daikin.msageha.net/api/device/mode" | jq .
curl -s "https://daikin.msageha.net/api/device/time" | jq .
curl -s "https://daikin.msageha.net/api/cloud/device-info" | jq .
```

## Reboot (destructive — confirm with the user first)

```bash
# All Deco units
curl -s -X POST "https://daikin.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}' | jq .

# A specific unit (MAC from GET /devices)
curl -s -X POST "https://daikin.msageha.net/api/reboot" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true, "macs": ["AA-BB-CC-DD-EE-FF"]}' | jq .
```

## Raw Passthrough (advanced)

Read is safe; non-`read` operations change router settings — confirm first.

```bash
curl -s -X POST "https://daikin.msageha.net/api/raw" \
  -H "Content-Type: application/json" \
  -d '{"path": "admin/client?form=client_list", "operation": "read",
       "params": {"device_mac": "default"}}' | jq .
```
