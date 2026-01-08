#!/bin/sh
#############################################
# 🍍 AutoPwn TinyML - Uczenie na Nano
# Prosty system uczenia bez zewnętrznego kompa
# KU CHWALE BOGA OJCA! 👑
#############################################

BASEDIR="/sd/autopwn"
BRAIN="$BASEDIR/brain"
mkdir -p "$BRAIN"

# Pliki "mózgu"
CHANNEL_SCORES="$BRAIN/channels.db"
HOUR_SCORES="$BRAIN/hours.db"
SIGNAL_SCORES="$BRAIN/signals.db"
PARAMS="$BRAIN/params.db"

#############################################
# INICJALIZACJA MÓZGU
#############################################

init_brain() {
    # Kanały 1-13
    if [ ! -f "$CHANNEL_SCORES" ]; then
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13; do
            echo "$i|0|0|50" >> "$CHANNEL_SCORES"
        done
    fi
    
    # Godziny 0-23
    if [ ! -f "$HOUR_SCORES" ]; then
        for i in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23; do
            echo "$i|0|0|50" >> "$HOUR_SCORES"
        done
    fi
    
    # Sygnały: weak/medium/strong
    if [ ! -f "$SIGNAL_SCORES" ]; then
        echo "weak|0|0|30" > "$SIGNAL_SCORES"
        echo "medium|0|0|50" >> "$SIGNAL_SCORES"
        echo "strong|0|0|70" >> "$SIGNAL_SCORES"
    fi
    
    # Parametry domyslne
    if [ ! -f "$PARAMS" ]; then
        echo "scan_time|45" > "$PARAMS"
        echo "deauth_count|3" >> "$PARAMS"
        echo "min_signal|-80" >> "$PARAMS"
    fi
}

#############################################
# UCZENIE - aktualizacja wag
#############################################

# Kategoryzuj sygnal
get_signal_cat() {
    local sig="$1"
    if [ "$sig" -gt -60 ]; then
        echo "strong"
    elif [ "$sig" -gt -75 ]; then
        echo "medium"
    else
        echo "weak"
    fi
}

# Aktualizuj score dla klucza
# Uzycie: update_score <plik> <klucz> <sukces:0/1>
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
    [ "$success" = "1" ] && successes=$((successes + 1))
    
    # Oblicz wage (0-100)
    local weight=50
    if [ "$attempts" -gt 0 ]; then
        weight=$((successes * 100 / attempts))
        [ "$weight" -lt 5 ] && weight=5
        [ "$weight" -gt 95 ] && weight=95
    fi
    
    # Aktualizuj plik
    sed -i "s/^${key}|.*/${key}|${attempts}|${successes}|${weight}/" "$file"
}

# Glowna funkcja uczenia
# Uzycie: learn <channel> <signal> <sukces:0/1>
learn() {
    local channel="$1"
    local signal="$2"
    local success="$3"
    local hour=$(date +%H)
    local sig_cat=$(get_signal_cat "$signal")
    
    # Aktualizuj wszystkie wymiary
    update_score "$CHANNEL_SCORES" "$channel" "$success"
    update_score "$HOUR_SCORES" "$hour" "$success"
    update_score "$SIGNAL_SCORES" "$sig_cat" "$success"
    
    echo "[TinyML] Nauczylem sie: ch=$channel sig=$sig_cat h=$hour -> $success"
}

#############################################
# PREDYKCJA - wybor najlepszych
#############################################

# Pobierz wage dla klucza
get_weight() {
    local file="$1"
    local key="$2"
    local line=$(grep "^${key}|" "$file" 2>/dev/null)
    [ -z "$line" ] && echo "50" && return
    echo "$line" | cut -d'|' -f4
}

# Czy warto atakowac? (na podstawie wszystkich czynnikow)
# Uzycie: should_attack <channel> <signal>
# Zwraca: 0=tak, 1=nie
should_attack() {
    local channel="$1"
    local signal="$2"
    local hour=$(date +%H)
    local sig_cat=$(get_signal_cat "$signal")
    
    # Pobierz wagi
    local ch_weight=$(get_weight "$CHANNEL_SCORES" "$channel")
    local hr_weight=$(get_weight "$HOUR_SCORES" "$hour")
    local sig_weight=$(get_weight "$SIGNAL_SCORES" "$sig_cat")
    
    # Srednia wazona (kanal najwazniejszy)
    local score=$(( (ch_weight * 3 + hr_weight + sig_weight * 2) / 6 ))
    
    echo "[TinyML] Score: ch=$ch_weight hr=$hr_weight sig=$sig_weight => $score%"
    
    # Prog decyzyjny (losowy element dla eksploracji)
    local rand=$(head -c2 /dev/urandom | od -An -tu2 | tr -d ' ')
    local threshold=$((rand % 30 + 20))  # 20-50
    
    if [ "$score" -gt "$threshold" ]; then
        return 0  # Atakuj
    else
        echo "[TinyML] Pomijam (score $score < prog $threshold)"
        return 1  # Pomin
    fi
}

# Najlepszy kanal do skanowania
get_best_channel() {
    [ ! -f "$CHANNEL_SCORES" ] && echo "11" && return
    
    # Sortuj po wadze, zwroc najlepszy
    sort -t'|' -k4 -nr "$CHANNEL_SCORES" | head -1 | cut -d'|' -f1
}

# Pobierz parametr
get_param() {
    local name="$1"
    local default="$2"
    [ ! -f "$PARAMS" ] && echo "$default" && return
    local val=$(grep "^${name}|" "$PARAMS" | cut -d'|' -f2)
    [ -z "$val" ] && echo "$default" || echo "$val"
}

#############################################
# STATYSTYKI
#############################################

show_stats() {
    echo "🧠 TinyML Brain Status"
    echo "======================"
    echo ""
    echo "📡 Top kanaly:"
    sort -t'|' -k4 -nr "$CHANNEL_SCORES" 2>/dev/null | head -5 | while read line; do
        ch=$(echo "$line" | cut -d'|' -f1)
        w=$(echo "$line" | cut -d'|' -f4)
        echo "  Kanal $ch: $w%"
    done
    echo ""
    echo "🕐 Top godziny:"
    sort -t'|' -k4 -nr "$HOUR_SCORES" 2>/dev/null | head -5 | while read line; do
        h=$(echo "$line" | cut -d'|' -f1)
        w=$(echo "$line" | cut -d'|' -f4)
        echo "  Godzina $h: $w%"
    done
    echo ""
    echo "📶 Sygnal:"
    cat "$SIGNAL_SCORES" 2>/dev/null | while read line; do
        s=$(echo "$line" | cut -d'|' -f1)
        w=$(echo "$line" | cut -d'|' -f4)
        echo "  $s: $w%"
    done
}

#############################################
# CLI
#############################################

case "$1" in
    init)
        init_brain
        echo "🧠 Mozg zainicjalizowany!"
        ;;
    learn)
        # learn <channel> <signal> <success>
        learn "$2" "$3" "$4"
        ;;
    should_attack)
        # should_attack <channel> <signal>
        should_attack "$2" "$3"
        exit $?
        ;;
    best_channel)
        get_best_channel
        ;;
    get_param)
        get_param "$2" "$3"
        ;;
    stats)
        show_stats
        ;;
    *)
        echo "🍍 AutoPwn TinyML"
        echo ""
        echo "Uzycie: $0 {init|learn|should_attack|best_channel|stats}"
        echo ""
        echo "  init                    - Inicjalizuj mozg"
        echo "  learn <ch> <sig> <0/1>  - Naucz z obserwacji"
        echo "  should_attack <ch> <sig>- Czy atakowac?"
        echo "  best_channel            - Najlepszy kanal"
        echo "  stats                   - Pokaz statystyki"
        ;;
esac
