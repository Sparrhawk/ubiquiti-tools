#!/bin/bash
# ==============================================================================
#  UDM PORT SCHEDULER
#  Schedule switch port enable/disable on Ubiquiti Dream Machine (Pro/SE/etc.)
#
#  Usage:  ./port-scheduler.sh enable
#          ./port-scheduler.sh disable
# ==============================================================================

# ──────────────────────────────────────────────────────────────────────────────
#  CONFIGURATION — EDIT THIS SECTION
# ──────────────────────────────────────────────────────────────────────────────

# UniFi controller address (use localhost if running on the UDM itself)
CONTROLLER="https://localhost"

# Login credentials (local admin account — NOT UniFi cloud SSO)
USERNAME="admin"
PASSWORD="your_password_here"

# Site name (usually "default" unless you renamed it)
SITE="default"

# ──────────────────────────────────────────────────────────────────────────────
#  PORTS TO CONTROL
#  Format:  "DEVICE_MAC:PORT_IDX"
#
#  DEVICE_MAC  = MAC address of the switch / UDM (lowercase, colon-separated)
#  PORT_IDX    = Port number (1-based index as shown in the UniFi UI)
#
#  Examples:
#    "aa:bb:cc:dd:ee:ff:1"   → Port 1 on device aa:bb:cc:dd:ee:ff
#    "aa:bb:cc:dd:ee:ff:5"   → Port 5 on the same device
#    "11:22:33:44:55:66:3"   → Port 3 on a different switch
#
#  Add or remove lines below to control whichever ports you need.
# ──────────────────────────────────────────────────────────────────────────────

PORTS=(
    "aa:bb:cc:dd:ee:ff:1"
    "aa:bb:cc:dd:ee:ff:2"
    "aa:bb:cc:dd:ee:ff:5"
    # "11:22:33:44:55:66:3"    # ← uncomment to add another device/port
)

# ──────────────────────────────────────────────────────────────────────────────
#  END OF CONFIGURATION — no edits needed below this line
# ──────────────────────────────────────────────────────────────────────────────

ACTION="${1:-}"
if [[ "$ACTION" != "enable" && "$ACTION" != "disable" ]]; then
    echo "Usage: $0 {enable|disable}"
    exit 1
fi

COOKIE_FILE=$(mktemp)
trap "rm -f $COOKIE_FILE" EXIT

CURL_OPTS="-ks --connect-timeout 10 --max-time 30"

# ── Step 1: Authenticate ─────────────────────────────────────────────────────
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Logging in to $CONTROLLER ..."

HTTP_CODE=$(curl $CURL_OPTS -o /dev/null -w "%{http_code}" \
    -X POST "$CONTROLLER/api/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"password\":\"$PASSWORD\"}" \
    -c "$COOKIE_FILE")

if [[ "$HTTP_CODE" != "200" ]]; then
    echo "[ERROR] Login failed (HTTP $HTTP_CODE). Check credentials & controller address."
    exit 1
fi
echo "[OK] Authenticated."

# ── Step 2: Toggle each port ─────────────────────────────────────────────────
if [[ "$ACTION" == "disable" ]]; then
    POE_MODE="off"
    PORT_ENABLED="false"
    echo "[INFO] Disabling ports ..."
else
    POE_MODE="auto"
    PORT_ENABLED="true"
    echo "[INFO] Enabling ports ..."
fi

SUCCESS=0
FAIL=0

for ENTRY in "${PORTS[@]}"; do
    # Parse  MAC:PORT_IDX
    DEVICE_MAC="${ENTRY%:*}"
    PORT_IDX="${ENTRY##*:}"

    echo -n "  → Device $DEVICE_MAC, Port $PORT_IDX ... "

    # Build the port override payload
    PAYLOAD=$(cat <<EOF
{
    "port_overrides": [
        {
            "port_idx": $PORT_IDX,
            "poe_mode": "$POE_MODE",
            "port_security_enabled": false
        }
    ]
}
EOF
)

    # Find the device ID for this MAC
    DEVICE_ID=$(curl $CURL_OPTS \
        -b "$COOKIE_FILE" \
        "$CONTROLLER/proxy/network/api/s/$SITE/stat/device/$DEVICE_MAC" \
        | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['data'][0]['_id'])
except:
    print('')
" 2>/dev/null)

    if [[ -z "$DEVICE_ID" ]]; then
        echo "FAILED (device not found)"
        ((FAIL++))
        continue
    fi

    # Apply port override
    HTTP_CODE=$(curl $CURL_OPTS -o /dev/null -w "%{http_code}" \
        -X PUT "$CONTROLLER/proxy/network/api/s/$SITE/rest/device/$DEVICE_ID" \
        -H "Content-Type: application/json" \
        -b "$COOKIE_FILE" \
        -d "$PAYLOAD")

    if [[ "$HTTP_CODE" == "200" ]]; then
        echo "OK"
        ((SUCCESS++))
    else
        echo "FAILED (HTTP $HTTP_CODE)"
        ((FAIL++))
    fi
done

echo ""
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Done. Success: $SUCCESS | Failed: $FAIL"

# ── Step 3: Logout ────────────────────────────────────────────────────────────
curl $CURL_OPTS -o /dev/null -X POST "$CONTROLLER/api/auth/logout" -b "$COOKIE_FILE"
