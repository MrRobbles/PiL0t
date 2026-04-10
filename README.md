[README.md](https://github.com/user-attachments/files/26637203/README.md)
# PiL0t

> A lightweight Raspberry Pi management console and ZPL print server — inspired by Webmin, built for speed.

---

## What is PiL0t?

If you've ever used **Webmin** to manage a Linux server through a browser, PiL0t is that idea rebuilt from scratch with a single target in mind: the **Raspberry Pi**.

Webmin is powerful but it's heavy. On a Pi 3B+ with limited RAM and a slow SD card, the interface can feel sluggish and the resource overhead is noticeable. PiL0t was built to solve that — a purpose-built management console that loads fast, stays responsive, and doesn't fight the hardware it's running on.

It also goes a step further. PiL0t isn't just a system manager — it's a full **ZPL label print server**. Plug in a Zebra printer, connect a USB keypad, and your Pi becomes a standalone inventory labelling station that works without any cloud dependency, network print drivers, or Windows PC in the loop.

The interface is dark, terminal-inspired, and designed to feel at home on the kind of hardware it runs on.

---

## Why not just use Webmin?

| | Webmin | PiL0t |
|---|---|---|
| Target hardware | General Linux servers | Raspberry Pi |
| Interface weight | Heavy — Perl, CGI, lots of JS frameworks | Lightweight — plain Flask, vanilla JS |
| RAM usage | 150–300MB typical | ~40MB typical |
| Boot time | Slow on Pi SD | Fast |
| ZPL print server | No | Built in |
| USB keypad support | No | Built in |
| Install | Complex | One line |

---

## Install

SSH into your Pi and run:

```bash
curl -fsSL https://raw.githubusercontent.com/MrRobbles/PiL0t/main/install.sh | sudo bash
```

That's it. The installer handles everything — dependencies, directory structure, systemd services, sudoers, and default config. On a Pi 3B+ with a decent SD card it takes under two minutes.

When it finishes, open your browser and go to:

```
http://<your-pi-ip>:5000
```

**Default login:** `admin` / `admin`
Change this immediately after first login.

---

## Requirements

**Hardware:**
- Raspberry Pi 3B+ or newer (tested on 3B+ and 4)
- Any storage — SD card, USB SSD, or eMMC
- Zebra ZD620 or any ZPL-compatible label printer (USB or network)
- PCsensor MK424BT 4-key USB keypad *(optional — for physical print buttons)*

**Software:**
- Raspberry Pi OS Bullseye or Bookworm (64-bit or 32-bit)
- Python 3.9 or newer *(pre-installed on all current Pi OS images)*

No other setup required. The installer handles everything else.

---

## Features

### Print Server
The core reason PiL0t exists. Connect a Zebra ZPL printer via USB or network and the Pi becomes a fully standalone label printing station.

- Print the next SKU in sequence with a single button press
- Reprint the last label at any time
- Print blank feed labels for calibration
- Custom label printing with any SKU number or free text
- Batch print a range of SKUs in one go
- Every print is timestamped and logged
- ZPL label format is configurable directly in the UI
- Printer IP, port, and label dimensions stored in config — no code editing needed

### USB Keypad Support
Physical buttons wired directly to the Pi via a USB HID keypad. No display, no mouse, no keyboard needed at the printer station.

| Button | Action |
|--------|--------|
| A | Print next SKU — increments counter automatically |
| B | Reprint last SKU — duplicates the previous label |
| C | Print blank label — feeds a blank for calibration |
| D | Reserved for future use |

Uses `evdev` to read the keypad at the kernel level — works headless with no display environment required.

### Performance Monitor
Live system metrics that update every 2 seconds without hammering the CPU. Shows everything you need to know about what the Pi is doing.

- CPU usage with per-core breakdown
- RAM and swap usage
- Disk usage across all mounted filesystems
- CPU temperature with thermal status indicator
- System uptime
- Running process count
- LED status indicators for printer, services, and network

### System Information
Hardware and OS details pulled directly from the Pi — model, revision, kernel version, architecture, hostname, and network interface status.

### Diagnostics
Network and process tools available directly in the browser without needing SSH.

- Ping any host and see latency
- Traceroute
- Port check — test if a TCP port is reachable
- Live process list with the ability to kill any process
- Hardware info

### Log Viewer
View and tail any service or system log directly in the browser.

- Live tail mode — streams new log lines in real time
- Switch between systemd services or arbitrary log files
- Print log — dedicated view of the SKU print history
- Login history and session log built in

### WiFi Management
Scan for nearby networks, connect, and manage saved profiles — all from the browser. Includes safeguards against accidentally disconnecting yourself.

- Scan and list available networks with signal strength sorted strongest first
- Connect using WPA/WPA2 with proper PSK hashing via `wpa_passphrase`
- Shows current connection status
- Disconnect from current network
- Clear all saved wifi profiles
- Locked automatically if you are already connected via WiFi with no ethernet cable plugged in — prevents stranding yourself

### Terminal
A full live bash session running directly in the browser. Built on xterm.js.

- Full interactive terminal — tab completion, arrow keys, colour output
- Scrollback buffer
- CLEAR button to reset the session
- Clipboard paste support

### File Browser
A complete file manager that works like a lightweight SFTP client without needing SFTP.

- Browse the full filesystem
- Upload files via drag-and-drop or file picker
- Download files
- Create directories
- Rename and delete
- Batch delete with multi-select
- Show/hide hidden files toggle
- Breadcrumb navigation

### Project Tools
Utilities for managing the PiL0t installation and any scripts running alongside it.

- **Script runner** — save and run shell scripts directly from the browser
- **Environment editor** — edit `.env` style config files in the UI
- **Cron manager** — view and edit crontab entries
- **Git integration** — check repo status and pull updates

### Auth and Session Management
App-level accounts that are completely separate from Linux system users.

- Multi-user with admin and standard roles
- SHA256 hashed passwords
- Session tracking — see who is logged in, from which IP, and when
- Force logout any active session with immediate server-side invalidation
- Login history log
- IP logging for all page visits including unauthenticated ones
- Configurable access control — lock specific sections behind login

### Maintenance
System-level controls accessible from the browser.

- `apt-get update` — refresh package lists with live streaming output
- `apt-get upgrade` — install updates with real-time progress visible line by line
- Empty trash
- Reboot with countdown timer and auto-reconnect
- Shutdown with a sequence of status messages before going offline

---

## Reboot and Shutdown

When you reboot from the UI, PiL0t shows a countdown and automatically reconnects the browser when the Pi comes back online. No manual refresh needed.

Shutdown scrolls through a short sequence of personality messages before going offline, then shows a final static screen when the Pi powers down.

---

## File locations

| Path | Purpose |
|------|---------|
| `/etc/pil0t/` | Application files |
| `/etc/pil0t/static/` | HTML/CSS/JS frontend |
| `/etc/pil0t/data/` | Config and persistent data |
| `/etc/pil0t/data/current_sku.txt` | SKU counter — edit to reset or jump |
| `/etc/pil0t/data/sku_log.txt` | Full print history |
| `/etc/pil0t/data/printer_config.json` | Printer IP and port |
| `/etc/pil0t/data/app_users.json` | User accounts |
| `/etc/pil0t/data/auth_config.json` | Access control settings |
| `/etc/pil0t/data/branding.json` | App title and subtitle |
| `/var/log/pil0t-network.log` | Boot network script log |

---

## Services

```bash
sudo systemctl status pil0t-web
sudo systemctl status pil0t-tracker

sudo journalctl -u pil0t-web -f
sudo journalctl -u pil0t-tracker -f
```

---

## Updating

To update PiL0t, re-run the installer. It preserves all data and config files:

```bash
curl -fsSL https://raw.githubusercontent.com/MrRobbles/PiL0t/main/install.sh | sudo bash
```

---

## Network behaviour on boot

PiL0t installs a boot script that runs on every startup:

1. Unblocks the wifi radio and brings `wlan0` up
2. Attempts to reconnect to the last known wifi network via `wpa_supplicant`
3. If wifi connects, gets an IP via `dhcpcd`
4. If wifi fails or is not configured, falls back to `eth0` DHCP
5. Logs the result to `/var/log/pil0t-network.log`

This means the Pi will always try to come back on the network after a reboot regardless of whether it was on wifi or ethernet previously.

---

## Resetting the SKU counter

The counter is a plain text file. Edit it any time:

```bash
cat /etc/pil0t/data/current_sku.txt
echo 2000 > /etc/pil0t/data/current_sku.txt
```

---

## Roadmap

- First launch setup wizard
- USB print mode (write ZPL directly to `/dev/usb/lp0`)
- Debian/Ubuntu server support
- Label template editor
- Multi-printer support

---

## Contributing

Issues and pull requests welcome. This project is actively developed and tested on real Pi hardware in a live warehouse environment.

---

## License

MIT
