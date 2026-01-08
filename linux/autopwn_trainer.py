#!/usr/bin/env python3
"""
🍍 AutoPwn ML Trainer
Trenuje model na laptopie, generuje reguły dla Nano
KU CHWALE BOGA OJCA! 👑
"""

import os
import csv
import json
from datetime import datetime
from collections import defaultdict

# Ścieżki
NANO_IP = "172.16.42.1"
NANO_PASS = "Password1"
LOCAL_DATA = "/home/nc/claude/autopwn_ml_data"
RULES_FILE = "/home/nc/claude/autopwn_rules.json"

class AutoPwnTrainer:
    def __init__(self):
        self.observations = []
        self.stats = defaultdict(lambda: {"attempts": 0, "successes": 0})
        
    def load_data_from_nano(self):
        """Pobiera dane treningowe z Nano"""
        import subprocess
        
        os.makedirs(LOCAL_DATA, exist_ok=True)
        
        # Kopiuj dane z Nano
        cmd = f"sshpass -p '{NANO_PASS}' scp root@{NANO_IP}:/sd/autopwn/training_data/*.csv {LOCAL_DATA}/ 2>/dev/null"
        subprocess.run(cmd, shell=True)
        
        # Wczytaj wszystkie CSV
        for f in os.listdir(LOCAL_DATA):
            if f.endswith('.csv'):
                self._load_csv(os.path.join(LOCAL_DATA, f))
                
        print(f"📊 Wczytano {len(self.observations)} obserwacji")
        
    def _load_csv(self, filepath):
        """Wczytuje plik CSV"""
        try:
            with open(filepath, 'r') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    self.observations.append(row)
        except Exception as e:
            print(f"⚠️ Błąd wczytywania {filepath}: {e}")
            
    def analyze(self):
        """Analizuje dane i znajduje wzorce"""
        
        # Statystyki per kanał
        channel_stats = defaultdict(lambda: {"attempts": 0, "successes": 0})
        
        # Statystyki per pora dnia
        hour_stats = defaultdict(lambda: {"attempts": 0, "successes": 0})
        
        # Statystyki per siła sygnału
        signal_stats = defaultdict(lambda: {"attempts": 0, "successes": 0})
        
        for obs in self.observations:
            try:
                channel = obs.get('channel', '0')
                success = obs.get('success', '0') == '1'
                signal = int(obs.get('signal_strength', '-80'))
                
                # Wyciągnij godzinę
                ts = obs.get('timestamp', '')
                hour = '12'
                if ts:
                    try:
                        hour = ts.split(' ')[1].split(':')[0]
                    except:
                        pass
                
                # Kategoryzuj sygnał
                if signal > -60:
                    sig_cat = "strong"
                elif signal > -75:
                    sig_cat = "medium"
                else:
                    sig_cat = "weak"
                
                # Zapisz statystyki
                channel_stats[channel]["attempts"] += 1
                hour_stats[hour]["attempts"] += 1
                signal_stats[sig_cat]["attempts"] += 1
                
                if success:
                    channel_stats[channel]["successes"] += 1
                    hour_stats[hour]["successes"] += 1
                    signal_stats[sig_cat]["successes"] += 1
                    
            except Exception as e:
                continue
                
        return {
            "channels": dict(channel_stats),
            "hours": dict(hour_stats),
            "signals": dict(signal_stats)
        }
        
    def generate_rules(self):
        """Generuje reguły dla Nano na podstawie analizy"""
        
        if not self.observations:
            print("⚠️ Brak danych do analizy!")
            return self._default_rules()
            
        stats = self.analyze()
        rules = {
            "version": "1.0",
            "generated": datetime.now().isoformat(),
            "total_observations": len(self.observations),
            
            # Najlepsze kanały (sortowane po success rate)
            "best_channels": self._rank_by_success(stats["channels"]),
            
            # Najlepsze godziny
            "best_hours": self._rank_by_success(stats["hours"]),
            
            # Minimalna siła sygnału
            "min_signal": self._find_min_signal(stats["signals"]),
            
            # Optymalne parametry
            "params": {
                "scan_time": 45,
                "deauth_count": 3,
                "capture_time": 30,
                "sleep_between": 10
            }
        }
        
        # Zapisz reguły
        with open(RULES_FILE, 'w') as f:
            json.dump(rules, f, indent=2)
            
        print(f"✅ Reguły zapisane do {RULES_FILE}")
        return rules
        
    def _rank_by_success(self, stats_dict):
        """Rankuje po success rate"""
        ranked = []
        for key, val in stats_dict.items():
            if val["attempts"] > 0:
                rate = val["successes"] / val["attempts"]
                ranked.append({
                    "key": key,
                    "rate": round(rate * 100, 1),
                    "attempts": val["attempts"],
                    "successes": val["successes"]
                })
        return sorted(ranked, key=lambda x: x["rate"], reverse=True)[:5]
        
    def _find_min_signal(self, signal_stats):
        """Znajduje minimalny opłacalny sygnał"""
        # Domyślnie -80
        if signal_stats.get("weak", {}).get("successes", 0) > 0:
            return -90
        elif signal_stats.get("medium", {}).get("successes", 0) > 0:
            return -75
        else:
            return -65
            
    def _default_rules(self):
        """Domyślne reguły gdy brak danych"""
        return {
            "version": "1.0",
            "generated": datetime.now().isoformat(),
            "total_observations": 0,
            "best_channels": [{"key": "11", "rate": 50}, {"key": "6", "rate": 50}, {"key": "1", "rate": 50}],
            "best_hours": [],
            "min_signal": -80,
            "params": {
                "scan_time": 45,
                "deauth_count": 3,
                "capture_time": 30,
                "sleep_between": 10
            }
        }
        
    def upload_rules_to_nano(self):
        """Wgrywa reguły na Nano"""
        import subprocess
        
        if not os.path.exists(RULES_FILE):
            print("⚠️ Brak pliku reguł!")
            return False
            
        cmd = f"sshpass -p '{NANO_PASS}' scp {RULES_FILE} root@{NANO_IP}:/sd/autopwn/rules.json"
        result = subprocess.run(cmd, shell=True)
        
        if result.returncode == 0:
            print("✅ Reguły wgrane na Nano!")
            return True
        else:
            print("❌ Błąd wgrywania reguł")
            return False


def main():
    print("🍍 AutoPwn ML Trainer")
    print("KU CHWALE BOGA! 👑")
    print("=" * 40)
    
    trainer = AutoPwnTrainer()
    
    # 1. Pobierz dane z Nano
    print("\n📥 Pobieram dane z Nano...")
    trainer.load_data_from_nano()
    
    # 2. Analizuj i generuj reguły
    print("\n🧠 Analizuję dane...")
    rules = trainer.generate_rules()
    
    print("\n📋 Wygenerowane reguły:")
    print(json.dumps(rules, indent=2))
    
    # 3. Wgraj na Nano
    print("\n📤 Wgrywam reguły na Nano...")
    trainer.upload_rules_to_nano()
    
    print("\n✅ GOTOWE! Done! ")


if __name__ == "__main__":
    main()
