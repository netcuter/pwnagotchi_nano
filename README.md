# 🍍 Pwnagotchi Nano

**Pwnagotchi-like WiFi hunter for Pineapple Nano with TinyML learning**

*!* 

## What is this?

A lightweight, autonomous WiFi handshake hunter inspired by [Pwnagotchi](https://pwnagotchi.ai/), but designed for the resource-constrained **WiFi Pineapple Nano** (60MB RAM, 500MHz MIPS CPU).

## Features

✅ **Autonomous hunting** - plug in, walk away, collect handshakes  
✅ **TinyML on-device learning** - learns best channels, times, signal strengths  
✅ **Hybrid learning** - advanced training on laptop when connected  
✅ **Safe operation** - never writes to flash, all data on SD card  
✅ **Target mode** - focus on specific network or hunt all  
✅ **BusyBox compatible** - pure shell scripts, no Python needed  

## TODO / Roadmap

- [ ] **PMKID attack** - capture without clients (like Pwnagotchi)
- [ ] **Dynamic parameters** - auto-adjust timeouts based on movement
- [ ] **Better reward function** - closer to Pwnagotchi's A2C approach
- [ ] **Bluetoothgotchi mode** - BT/BLE scanning with USB adapter
- [ ] **E-ink display support** - show status on small screen
- [ ] **Mesh networking** - multiple units cooperating

## Hardware

- WiFi Pineapple Nano (Hak5)
- SD Card (recommended 8GB+)
- USB power source

## Installation

```bash
# Copy scripts to Pineapple
scp autopwn.sh root@172.16.42.1:/sd/autopwn/
scp autopwn_tinyml.sh root@172.16.42.1:/sd/autopwn/

# Initialize brain
ssh root@172.16.42.1 "/sd/autopwn/autopwn_tinyml.sh init"

# Start hunting!
ssh root@172.16.42.1 "/sd/autopwn/autopwn.sh start"
```

## Usage

```bash
# Start autonomous mode
/sd/autopwn/autopwn.sh start

# Check status
/sd/autopwn/autopwn.sh status

# View captured handshakes
/sd/autopwn/autopwn.sh cracked

# TinyML brain stats
/sd/autopwn/autopwn_tinyml.sh stats

# Set target network (or PWNAGOTCHI for all)
echo "MODE=MyWiFiNetwork" > /sd/autopwn/target.txt
```

## How TinyML Learning Works

The device learns on its own without external computer:

1. **Channels** - which WiFi channels have best success rate
2. **Hours** - what time of day works best  
3. **Signal strength** - minimum dBm worth attacking

Data stored in `/sd/autopwn/brain/`:
```
channels.db  - success rate per channel (1-13)
hours.db     - success rate per hour (0-23)
signals.db   - success rate per signal category
```

## Hybrid Training (Optional)

When connected to laptop via USB:

```bash
# On laptop (WSL/Linux)
python3 autopwn_trainer.py
```

This pulls data from Nano, trains better model, uploads optimized rules.

## Comparison with Pwnagotchi

| Feature | Pwnagotchi | Pwnagotchi Nano |
|---------|------------|-----------------|
| Hardware | Raspberry Pi | Pineapple Nano |
| RAM | 512MB+ | 60MB |
| AI | Neural Network (A2C) | TinyML (statistics) |
| Techniques | Deauth + PMKID | Deauth (PMKID TODO) |
| Display | E-ink | None (TODO) |
| Learning | On-device | On-device + laptop |

## Legal Disclaimer

⚠️ **FOR EDUCATIONAL AND AUTHORIZED TESTING ONLY** ⚠️

Only use on networks you own or have explicit permission to test. Unauthorized access to computer networks is illegal.

## Credits

- Inspired by [Pwnagotchi](https://pwnagotchi.ai/) by @evilsocket
- Built for [WiFi Pineapple](https://hak5.org/) by Hak5
- Created with help from Claude AI

## License

MIT License - do whatever you want, just don't be evil! 😈

---

*"The harvest is plentiful, but the workers are few."* - Matthew 9:37

**Done!** 
