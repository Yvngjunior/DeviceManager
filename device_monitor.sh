#!/data/data/com.termux/files/usr/bin/bash
# Professional All-in-One Termux Device Monitor

# ---- SETTINGS ----
INTERVAL=300                        # Check every 5 minutes
LOG="$HOME/device_monitor_table.txt" # Table log file
LAST_SSID=""
LOW_BAT=20
HIGH_BAT=90
USE_WAKE_LOCK=true

# ---- COLORS ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No color

# ---- FUNCTIONS ----
notify() { termux-notification --title "Device Monitor" --content "$1"; }
speak()  { termux-tts-speak "$1" >/dev/null 2>&1 || true; }
vibe()   { termux-vibrate -d 400 >/dev/null 2>&1 || true; }

# ---- CLEANUP ----
cleanup() {
    $USE_WAKE_LOCK && termux-wake-unlock || true
    notify "Device Monitor stopped at $(date '+%F %T')"
}
trap cleanup INT TERM

# ---- WAKE LOCK ----
$USE_WAKE_LOCK && termux-wake-lock

notify "Device Monitor started..."
echo -e "${CYAN}=== Device Monitor Started $(date '+%F %T') ===${NC}"

# ---- CREATE LOG FILE WITH HEADER ----
if [ ! -f "$LOG" ]; then
    printf "%-20s | %-15s | %-15s | %-10s | %-10s | %-20s | %-10s\n" \
    "Timestamp" "Battery(%)" "Status/Health" "Latitude" "Longitude" "SSID" "Signal" > "$LOG"
    printf -- "-------------------------------------------------------------------------------------------------------------\n" >> "$LOG"
fi

# ---- MAIN LOOP ----
while :; do
    TIMESTAMP=$(date '+%F %T')

    # --- BATTERY ---
    batt=$(termux-battery-status)
    PERCENT=$(echo "$batt" | jq '.percentage')
    STATUS=$(echo "$batt" | jq -r '.status')
    HEALTH=$(echo "$batt" | jq -r '.health')

    # Battery color for terminal
    if [ "$PERCENT" -le "$LOW_BAT" ]; then BAT_COLOR="$RED"
    elif [ "$PERCENT" -ge "$HIGH_BAT" ]; then BAT_COLOR="$GREEN"
    else BAT_COLOR="$YELLOW"
    fi

    # --- LOCATION ---
    loc=$(termux-location -p gps,network -r 100)
    LAT=$(echo "$loc" | jq -r '.latitude')
    LON=$(echo "$loc" | jq -r '.longitude')
    ACC=$(echo "$loc" | jq -r '.accuracy')

    # --- WIFI ---
    wifi=$(termux-wifi-connectioninfo)
    SSID=$(echo "$wifi" | jq -r '.ssid // "N/A"')
    BSSID=$(echo "$wifi" | jq -r '.bssid // "N/A"')
    IP=$(echo "$wifi" | jq -r '.ip // "N/A"')
    RSSI=$(echo "$wifi" | jq -r '.rssi // "N/A"')

    # --- Wi-Fi signal bars ---
    if [ "$RSSI" != "N/A" ]; then
        if [ "$RSSI" -ge -50 ]; then SIGNAL_BAR="▂▄▆█▁"; SIGNAL_COLOR="$GREEN"
        elif [ "$RSSI" -ge -60 ]; then SIGNAL_BAR="▂▄▆▁▁"; SIGNAL_COLOR="$YELLOW"
        elif [ "$RSSI" -ge -70 ]; then SIGNAL_BAR="▂▄▁▁▁"; SIGNAL_COLOR="$YELLOW"
        else SIGNAL_BAR="▂▁▁▁▁"; SIGNAL_COLOR="$RED"; fi
    else
        SIGNAL_BAR="-----"; SIGNAL_COLOR="$RED"
    fi

    # --- LOG TO FILE ---
    printf "%-20s | %-15s | %-15s | %-10s | %-10s | %-20s | %-10s\n" \
    "$TIMESTAMP" "$PERCENT" "$STATUS/$HEALTH" "$LAT" "$LON" "$SSID" "$RSSI dBm" >> "$LOG"

    # --- TERMINAL DASHBOARD ---
    clear
    echo -e "${MAGENTA}=== Device Monitor ===${NC}"
    echo -e "Battery: ${BAT_COLOR}$PERCENT% ($STATUS/$HEALTH)${NC}"
    echo -e "Location: ${CYAN}$LAT,$LON${NC} (Acc:${ACC}m)"
    echo -e "Wi-Fi: ${SIGNAL_COLOR}$SSID${NC} | Signal: $SIGNAL_BAR ($RSSI dBm) | IP:$IP"
    echo -e "Last Updated: $TIMESTAMP"
    echo -e "${MAGENTA}=====================${NC}"

    # --- ALERTS ---
    # Battery alerts
    if [ "$PERCENT" -le "$LOW_BAT" ] && [ "$STATUS" != "CHARGING" ]; then
        msg="⚠️ Battery low: $PERCENT%"
        notify "$msg"; speak "$msg"; vibe
    elif [ "$PERCENT" -ge "$HIGH_BAT" ] && [ "$STATUS" = "CHARGING" ]; then
        msg="🔋 Battery high: $PERCENT%"
        notify "$msg"; speak "$msg"; vibe
    fi

    # Wi-Fi change alert
    if [ "$SSID" != "$LAST_SSID" ]; then
        msg="📶 Connected to Wi-Fi: $SSID"
        notify "$msg"; speak "$msg"; vibe
        LAST_SSID="$SSID"
    fi

    sleep "$INTERVAL"
done
