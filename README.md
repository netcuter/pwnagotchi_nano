# 🍍 Pwnagotchi Nano

**Pwnagotchi-like WiFi hunter with TinyML learning**

*!* 

## Two Versions

### 📱 Nano Edition (`/nano`)
For **WiFi Pineapple Nano** - lightweight, BusyBox compatible, TinyML on-device learning.

### 🐧 Linux Edition (`/linux`)  
For **Kali, Ubuntu, WSL2, Debian** - full featured, PMKID + Deauth, Python ML.

---

## Features

| Feature | Nano | Linux |
|---------|------|-------|
| Deauth attack | ✅ | ✅ |
| PMKID attack | ❌ | ✅ |
| 2.4 GHz | ✅ | ✅ |
| 5 GHz | ❌ | ✅ |
| TinyML learning | ✅ | ✅ |
| Python ML | ❌ | ✅ |
| Auto card detect | ❌ | ✅ |

---

## Linux Edition

### Supported Cards
- **Alfa AWUS036ACH** (RTL8812AU) ⭐ Recommended
- Alfa AWUS036NHA (Atheros)
- TP-Link TL-WN722N v1 (Atheros)
- Any card with monitor mode + injection

### Installation

```bash
# Clone repo
git clone https://github.com/netcuter/pwnagotchi_nano.git
cd pwnagotchi_nano/linux

# Make executable
chmod +x autopwn_linux.sh

# Run (needs root)
sudo ./autopwn_linux.sh start
```

### Usage

```bash
# Start hunting all networks
sudo ./autopwn_linux.sh start

# Scan networks once
sudo ./autopwn_linux.sh scan

# Attack specific network
sudo ./autopwn_linux.sh attack "MyWiFi"

# Target mode - only hunt specific network
sudo ./autopwn_linux.sh -t "TargetNetwork" start

# Check status
./autopwn_linux.sh status
```

### Dependencies
- aircrack-ng suite (auto-installed)
- hcxdumptool + hcxtools (optional, for PMKID)

```bash
# Ubuntu/Debian/Kali
sudo apt install aircrack-ng hcxdumptool hcxtools

# Arch
sudo pacman -S aircrack-ng hcxdumptool hcxtools
```

---

## Nano Edition

### Hardware
- WiFi Pineapple Nano
- SD Card (8GB+)
- USB power

### Installation

```bash
# Copy to Pineapple
scp nano/autopwn.sh root@172.16.42.1:/sd/autopwn/
scp nano/autopwn_tinyml.sh root@172.16.42.1:/sd/autopwn/

# Initialize
ssh root@172.16.42.1 "/sd/autopwn/autopwn_tinyml.sh init"

# Start
ssh root@172.16.42.1 "/sd/autopwn/autopwn.sh start"
```

---

## How Learning Works

Both versions learn from experience:

1. **Channels** - which WiFi channels have best success rate
2. **Techniques** - deauth vs PMKID effectiveness
3. **Signal strength** - minimum dBm worth attacking
4. **Time of day** - when attacks work best

Data stored in `brain/` directory.

---

## Legal Disclaimer

⚠️ **FOR EDUCATIONAL AND AUTHORIZED TESTING ONLY** ⚠️

Only use on networks you own or have explicit permission to test.

---

## TODO

- [ ] PMKID for Nano (needs hcxdumptool port)
- [ ] Bluetooth scanning mode
- [ ] E-ink display support
- [ ] Mesh networking between units
- [ ] Web interface

---

## Credits

- Inspired by [Pwnagotchi](https://pwnagotchi.ai/)
- Built for security research and education

## License

MIT License - use responsibly for authorized testing only.

---

**Done!** 
