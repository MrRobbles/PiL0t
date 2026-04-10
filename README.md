# PiL0t

**Raspberry Pi management console and ZPL print server.**

A self-hosted web UI for managing a Raspberry Pi and Zebra label printer. Built for warehouse and inventory environments where you need reliable SKU label printing without cloud dependency.

---

## Install

SSH into your Pi and run:

```bash
curl -fsSL https://raw.githubusercontent.com/YOURUSER/pil0t/main/install.sh | sudo bash
```

That's it. Open `http://<your-pi-ip>:5000` when it finishes.

**Default login:** `admin` / `admin` — change it after first login.

---

## Requirements

- Raspberry Pi 3B+ or newer
- Raspberry Pi OS (Bullseye or Bookworm)
- Zebra ZD620 or compatible ZPL printer (USB or network)
- PCsensor MK424BT 4-key USB keypad (optional — for physical print buttons)

---

## Features

- **Print server** — Print next SKU, reprint, blank label via web UI or USB keypad
- **System management** — CPU/memory/disk metrics, live performance graphs
- **Terminal** — Live bash session in browser
- **File browser** — Full file manager with upload/download
- **WiFi management** — Scan, connect, manage networks
- **Log viewer** — Live service and file log tailing
- **Auth** — Multi-user with session management and IP logging
- **Auto-update** — One-click updates from GitHub

---

## Keypad button mapping (PCsensor MK424BT)

| Button | Action |
|--------|--------|
| A | Print next SKU + increment counter |
| B | Reprint last SKU |
| C | Print blank label |
| D | Reserved |

---

## File locations

| Path | Purpose |
|------|---------|
| `/etc/pil0t/` | Application files |
| `/etc/pil0t/data/` | Config and data files |
| `/etc/pil0t/data/current_sku.txt` | Current SKU counter |
| `/etc/pil0t/data/sku_log.txt` | Print history log |
| `/etc/pil0t/data/printer_config.json` | Printer IP and port |
| `/etc/pil0t/data/app_users.json` | User accounts |

---

## Services

```bash
sudo systemctl status pil0t-web       # Web UI
sudo systemctl status pil0t-tracker   # Keypad listener

sudo journalctl -u pil0t-web -f       # Live web logs
sudo journalctl -u pil0t-tracker -f   # Live keypad logs
```

---

## Update

From the web UI: **System Management → Maintenance → Check for Updates**

Or manually:
```bash
curl -fsSL https://raw.githubusercontent.com/YOURUSER/pil0t/main/install.sh | sudo bash
```

The installer preserves all data and config files on update.

---

## License

MIT
