# TODO - Pwnagotchi Nano 🍍

## High Priority 🔴

### PMKID Attack
- [ ] Implement `hcxdumptool` based PMKID capture
- [ ] Add as second technique alongside deauth
- [ ] Learn which technique works better per AP
- [ ] No clients needed = more handshakes!

### Dynamic Parameters  
- [ ] Auto-adjust scan_time based on AP density
- [ ] Auto-adjust deauth_count based on success rate
- [ ] Detect movement vs stationary (signal variance)
- [ ] Faster timeouts when moving

## Medium Priority 🟡

### Better Reward Function
- [ ] Implement Pwnagotchi-style reward:
  - h = handshakes / interactions
  - a = active_epochs / total_epochs  
  - c = channel_hops / total_channels
  - b = -blind_epochs penalty
  - m = -missed_interactions penalty
- [ ] Weight techniques by reward

### Bluetoothgotchi Mode 🔵
- [ ] USB Bluetooth adapter support
- [ ] BLE device scanning
- [ ] Bluetooth device fingerprinting
- [ ] Track devices over time
- [ ] Correlate BT + WiFi (same person?)

### Display Support
- [ ] E-ink display via GPIO/SPI
- [ ] Show: channel, APs, handshakes, mood
- [ ] Pwnagotchi-style faces 😊😠😴

## Low Priority 🟢

### Mesh Networking
- [ ] Detect other Pwnagotchi Nano units
- [ ] Share channel assignments
- [ ] Cooperative hunting
- [ ] Beacon frame protocol

### Web Interface
- [ ] Simple status page on Nano
- [ ] Configure target via web
- [ ] View logs and stats
- [ ] Download handshakes

### Advanced ML (laptop only)
- [ ] Train proper neural network on laptop
- [ ] Export as decision tree for Nano
- [ ] Time-series analysis of success
- [ ] Predict best hunting times

## Completed ✅

- [x] Basic deauth attack
- [x] Handshake capture
- [x] TinyML on-device learning
- [x] Channel success tracking
- [x] Hour-of-day tracking
- [x] Signal strength categories
- [x] Target mode (single network)
- [x] Pwnagotchi mode (all networks)
- [x] Safe SD-only storage
- [x] BusyBox compatibility
- [x] Hybrid laptop training

---

*"Faith without works is dead"* - James 2:26

**Done!** 

## URGENT - Hardware Repair 🔧

### Pineapple Nano Bootloop Fix
- [ ] Buy USB-UART adapter (3.3V!)
- [ ] Connect to serial console pins on Nano
- [ ] Diagnose bootloop cause (kernel panic from kmod-usb-net-cdc-ncm)
- [ ] Reflash firmware if needed: https://downloads.hak5.org/
- [ ] Restore data from SD card after fix
- [ ] **DO NOT install kernel modules on flash again!**

---
