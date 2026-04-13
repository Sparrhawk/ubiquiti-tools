#!/bin/bash
# ==============================================================================
#  DEVICE & PORT DISCOVERY HELPER
#  Run this first to find the MAC addresses and port indexes for your switches.
# ==============================================================================

CONTROLLER="https://localhost"
USERNAME="admin"
PASSWORD="your_password_here"
SITE="default"

COOKIE_FILE=$(mktemp)
trap "rm -f $COOKIE_FILE" EXIT
CURL_OPTS="-ks --connect-timeout 10 --max-time 30"

# Login
curl $CURL_OPTS -o /dev/null \
    -X POST "$CONTROLLER/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
    -c "$COOKIE_FILE"

echo "=============================================="
echo "  DEVICES & PORTS ON YOUR UNIFI NETWORK"
echo "=============================================="
echo ""

# Fetch all devices and display switch ports
curl $CURL_OPTS -b "$COOKIE_FILE" \
    "$CONTROLLER/proxy/network/api/s/$SITE/stat/device" \
    | python3 -c "
import sys, json

data = json.load(sys.stdin).get('data', [])
for dev in data:
    name = dev.get('name', dev.get('model', 'Unknown'))
    mac  = dev.get('mac', 'N/A')
    model = dev.get('model', '')
    dtype = dev.get('type', '')

    # Only show devices with switch ports
    ports = dev.get('port_table', [])
    if not ports:
        continue

    print(f'Device: {name}')
    print(f'  MAC:   {mac}')
    print(f'  Model: {model}  |  Type: {dtype}')
    print(f'  Ports:')
    print(f'  {\"#\":<5} {\"Name\":<20} {\"Speed\":<12} {\"PoE\":<10} {\"Enabled\":<10} {\"Config Key\"}')
    print(f'  {\"-\"*85}')
    for p in ports:
        idx     = p.get('port_idx', '?')
        pname   = p.get('name', f'Port {idx}')
        speed   = p.get('speed', 0)
        poe     = p.get('poe_mode', 'N/A')
        enabled = p.get('up', False)
        speed_s = f'{speed}M' if speed else 'Down'
        key     = f'{mac}:{idx}'
        print(f'  {idx:<5} {pname:<20} {speed_s:<12} {poe:<10} {str(enabled):<10} {key}')
    print()
" 2>/dev/null

# Logout
curl $CURL_OPTS -o /dev/null -X POST "$CONTROLLER/api/auth/logout" -b "$COOKIE_FILE"

echo ""
echo "Copy the 'Config Key' values above into the PORTS=() array in port-scheduler.sh"
