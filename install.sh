#!/bin/bash
# PiL0t Installer v1.0.1
# Usage: curl -fsSL https://raw.githubusercontent.com/MrRobbles/PiL0t/main/install.sh | sudo bash

# ── Safety ────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="https://raw.githubusercontent.com/MrRobbles/PiL0t/main"
INSTALL_DIR="/etc/pil0t"
DATA_DIR="/etc/pil0t/data"
STATIC_DIR="/etc/pil0t/static"
VERSION="1.0.0"

# Detect the real user (works whether piped from curl or run directly)
if [ -n "${SUDO_USER:-}" ]; then
    SERVICE_USER="$SUDO_USER"
elif [ -n "${USER:-}" ] && [ "$USER" != "root" ]; then
    SERVICE_USER="$USER"
else
    SERVICE_USER=$(logname 2>/dev/null || echo "pi")
fi

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; DIM='\033[2m'; RED='\033[0;31m'; BOLD='\033[1m'; AMBER='\033[0;33m'; NC='\033[0m'
header() { echo -e "\n${BOLD}${GREEN}▶ $1${NC}"; }
ok()     { echo -e "  ${GREEN}✓${NC} $1"; }
info()   { echo -e "  ${DIM}· $1${NC}"; }
warn()   { echo -e "  ${AMBER}⚠ $1${NC}"; }
err()    { echo -e "\n  ${RED}✗ ERROR: $1${NC}\n"; exit 1; }

# ── Banner ────────────────────────────────────────────────────────────────────
clear
echo -e "${GREEN}"
cat << 'BANNER'
  ____  _ _     ___  _
 |  _ \(_) |   / _ \| |_
 | |_) | | |  | | | | __|
 |  __/| | |__| |_| | |_
 |_|   |_|_____\___/ \__|

BANNER
echo -e "${NC}${DIM}  Raspberry Pi Management & Print Server${NC}"
echo -e "${DIM}  Version ${VERSION}${NC}\n"

# ── Must run as root ──────────────────────────────────────────────────────────
header "Checking environment"
[ "$EUID" -ne 0 ] && err "Run with sudo:\n  curl -fsSL $REPO/install.sh | sudo bash"
ok "Running as root (installing for user: $SERVICE_USER)"

# ── Check Pi OS ───────────────────────────────────────────────────────────────
if grep -qi "raspberry" /proc/cpuinfo 2>/dev/null || grep -qi "raspberry" /etc/os-release 2>/dev/null; then
    ok "Raspberry Pi detected"
else
    warn "Could not confirm Raspberry Pi hardware — continuing anyway"
fi

# ── Check internet ────────────────────────────────────────────────────────────
header "Checking connectivity"
if curl -fsSL --max-time 10 https://github.com > /dev/null 2>&1; then
    ok "Internet reachable"
else
    err "Cannot reach GitHub. Check your network connection and try again."
fi

# ── System packages ───────────────────────────────────────────────────────────
header "Updating package lists"
apt-get update -y -qq 2>&1 | tail -1
ok "Package lists updated"

header "Installing system packages"
PKGS=(python3 python3-pip curl git python3-flask)
for pkg in "${PKGS[@]}"; do
    if dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        ok "$pkg (already installed)"
    else
        info "Installing $pkg..."
        apt-get install -y -qq "$pkg" 2>/dev/null && ok "$pkg installed" || warn "$pkg install failed — will try pip fallback"
    fi
done

# ── Python packages ───────────────────────────────────────────────────────────
header "Installing Python packages"
PIP_PKGS=(flask flask-cors flask-sock evdev)

# Detect whether --break-system-packages is needed (Python 3.11+)
BREAK_FLAG=""
python3 -c "import sys; exit(0 if sys.version_info >= (3,11) else 1)" 2>/dev/null && BREAK_FLAG="--break-system-packages"

for pkg in "${PIP_PKGS[@]}"; do
    # Check if already importable
    PKG_IMPORT=$(echo "$pkg" | sed 's/-/_/g' | sed 's/flask_sock/flask_sock/' | sed 's/flask-cors/flask_cors/')
    if python3 -c "import $PKG_IMPORT" 2>/dev/null; then
        ok "$pkg (already installed)"
    else
        info "Installing $pkg..."
        pip3 install "$pkg" $BREAK_FLAG -q 2>/dev/null && ok "$pkg" || \
        pip3 install "$pkg" -q 2>/dev/null && ok "$pkg" || \
        warn "$pkg may not have installed correctly"
    fi
done

# ── Directories ───────────────────────────────────────────────────────────────
header "Creating directory structure"
mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$STATIC_DIR"
ok "$INSTALL_DIR"
ok "$DATA_DIR"
ok "$STATIC_DIR"

# ── Download application files ────────────────────────────────────────────────
header "Downloading PiL0t"

download() {
    local url="$1"
    local dest="$2"
    local label="$3"
    info "Downloading $label..."
    if curl -fsSL --max-time 30 "$url" -o "$dest"; then
        # Verify it's not an empty file or a GitHub 404 page
        if [ -s "$dest" ] && ! grep -q "404: Not Found" "$dest" 2>/dev/null; then
            ok "$label"
        else
            rm -f "$dest"
            err "Downloaded $label but it appears empty or invalid. Check your GitHub repo URL."
        fi
    else
        err "Failed to download $label from $url"
    fi
}

download "$REPO/app.py"                      "$INSTALL_DIR/app.py"              "app.py"
download "$REPO/print_sku.py"                "$INSTALL_DIR/print_sku.py"        "print_sku.py"
download "$REPO/static/index.html"           "$STATIC_DIR/index.html"           "static/index.html"
download "$REPO/static/system.html"          "$STATIC_DIR/system.html"          "static/system.html"
download "$REPO/static/filebrowser.html"     "$STATIC_DIR/filebrowser.html"     "static/filebrowser.html"
download "$REPO/static/login.html"              "$STATIC_DIR/login.html"           "static/login.html"

echo "$VERSION" > "$INSTALL_DIR/version.txt"
ok "version.txt"

# ── Default config (skip if already exists — safe to re-run) ─────────────────
header "Setting up configuration"

if [ ! -f "$DATA_DIR/printer_config.json" ]; then
    echo '{"printer_ip": "10.10.10.249", "printer_port": 9100}' > "$DATA_DIR/printer_config.json"
    ok "printer_config.json (default: 10.10.10.249:9100)"
else
    ok "printer_config.json (existing — not overwritten)"
fi

if [ ! -f "$DATA_DIR/current_sku.txt" ]; then
    echo "1490" > "$DATA_DIR/current_sku.txt"
    ok "current_sku.txt (starting SKU: 1490)"
else
    ok "current_sku.txt (existing — not overwritten)"
fi

if [ ! -f "$DATA_DIR/branding.json" ]; then
    echo '{"title": "PiL0t", "subtitle": "PRINT SERVER"}' > "$DATA_DIR/branding.json"
    ok "branding.json"
else
    ok "branding.json (existing — not overwritten)"
fi

if [ ! -f "$DATA_DIR/auth_config.json" ]; then
    echo '{"guest_print": true, "protected": {"system": true, "files": true, "terminal": true}}' > "$DATA_DIR/auth_config.json"
    ok "auth_config.json"
else
    ok "auth_config.json (existing — not overwritten)"
fi

if [ ! -f "$DATA_DIR/app_users.json" ]; then
    # admin/admin — SHA256 of "admin"
    echo '[{"username":"admin","password":"8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918","role":"admin"}]' > "$DATA_DIR/app_users.json"
    ok "app_users.json (login: admin / admin)"
else
    ok "app_users.json (existing — not overwritten)"
fi

[ ! -f "$DATA_DIR/sku_log.txt" ] && touch "$DATA_DIR/sku_log.txt"
ok "sku_log.txt"

# ── Permissions ───────────────────────────────────────────────────────────────
header "Setting permissions"
chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR" 2>/dev/null || \
    warn "Could not chown $INSTALL_DIR to $SERVICE_USER — may need manual fix"
chmod -R 755 "$INSTALL_DIR"
chmod 600 "$DATA_DIR/app_users.json"
ok "Permissions set (owner: $SERVICE_USER)"

# ── Sudoers ───────────────────────────────────────────────────────────────────
header "Configuring sudoers"
cat > /etc/sudoers.d/pil0t << SUDOERS
$SERVICE_USER ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /sbin/reboot, /sbin/shutdown, /bin/systemctl, /usr/bin/systemctl, /usr/bin/sysctl, /usr/sbin/iwlist, /usr/bin/ip, /sbin/ip, /bin/ip, /bin/cp, /bin/chmod, /usr/sbin/wpa_cli, /usr/bin/hostnamectl, /bin/sed, /usr/bin/tee, /usr/bin/rfkill, /sbin/iptables, /usr/sbin/wpa_supplicant, /usr/sbin/dhcpcd, /usr/bin/killall
SUDOERS
chmod 440 /etc/sudoers.d/pil0t
ok "Sudoers configured for $SERVICE_USER"

# ── Systemd services ──────────────────────────────────────────────────────────
header "Installing systemd services"

# Write service files directly — no curl needed, avoids download failures
cat > /etc/systemd/system/pil0t-web.service << SERVICE
[Unit]
Description=PiL0t Web UI
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/pil0t/app.py
WorkingDirectory=/etc/pil0t
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=5
User=$SERVICE_USER

[Install]
WantedBy=multi-user.target
SERVICE
ok "pil0t-web.service"

cat > /etc/systemd/system/pil0t-tracker.service << SERVICE
[Unit]
Description=PiL0t Keypad Tracker
After=network.target

[Service]
ExecStart=/usr/bin/python3 /etc/pil0t/print_sku.py
WorkingDirectory=/etc/pil0t
StandardOutput=journal
StandardError=journal
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE
ok "pil0t-tracker.service"

systemctl daemon-reload
systemctl enable pil0t-web  2>/dev/null
systemctl enable pil0t-tracker 2>/dev/null

# Start web service
systemctl restart pil0t-web
sleep 2
if systemctl is-active --quiet pil0t-web; then
    ok "pil0t-web started successfully"
else
    warn "pil0t-web failed to start — check: sudo journalctl -u pil0t-web -n 20"
fi

# Start tracker (needs keypad — failure is non-fatal)
systemctl restart pil0t-tracker 2>/dev/null || true
sleep 1
if systemctl is-active --quiet pil0t-tracker; then
    ok "pil0t-tracker started (keypad detected)"
else
    warn "pil0t-tracker not started (plug in USB keypad and run: sudo systemctl start pil0t-tracker)"
fi

# ── Network boot script ───────────────────────────────────────────────────────
header "Installing network boot script"
cat > /etc/network/if-up.d/pil0t-network << 'NETSCRIPT'
#!/bin/bash
LOG="/var/log/pil0t-network.log"
echo "$(date): PiL0t network startup" >> $LOG
rfkill unblock wifi 2>/dev/null
ip link set wlan0 up 2>/dev/null
sleep 1
if ! pgrep -x wpa_supplicant > /dev/null; then
    wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf 2>> $LOG
    sleep 5
else
    wpa_cli -i wlan0 reconfigure 2>> $LOG
    sleep 5
fi
SSID=$(iwgetid wlan0 --raw 2>/dev/null)
if [ -n "$SSID" ]; then
    echo "$(date): WiFi connected: $SSID" >> $LOG
    dhcpcd wlan0 2>> $LOG
else
    echo "$(date): WiFi not available, using eth0 DHCP" >> $LOG
    ip link set eth0 up 2>/dev/null
    dhcpcd eth0 2>> $LOG
fi
echo "$(date): eth0=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet )\S+') wlan0=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet )\S+')" >> $LOG
NETSCRIPT
chmod +x /etc/network/if-up.d/pil0t-network
ok "Network boot script installed"

# ── Summary ───────────────────────────────────────────────────────────────────
IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
[ -z "$IP" ] && IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
[ -z "$IP" ] && IP="<your-pi-ip>"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  PiL0t installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  Open in browser:   ${BOLD}http://$IP:5000${NC}"
echo -e "  Default login:     ${BOLD}admin / admin${NC}"
echo -e "  Install location:  ${BOLD}/etc/pil0t${NC}"
echo -e "  Data location:     ${BOLD}/etc/pil0t/data${NC}"
echo ""
echo -e "  ${DIM}Live logs:  sudo journalctl -u pil0t-web -f${NC}"
echo -e "  ${DIM}Restart:    sudo systemctl restart pil0t-web${NC}"
echo -e "  ${DIM}Stop:       sudo systemctl stop pil0t-web${NC}"
echo ""
echo -e "  ${RED}${BOLD}⚠  Change the default admin password after first login!${NC}"
echo ""
