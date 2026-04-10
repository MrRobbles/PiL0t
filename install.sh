#!/bin/bash
# PiL0t Installer
# Usage: curl -fsSL https://raw.githubusercontent.com/YOURUSER/pil0t/main/install.sh | bash

set -e

REPO="https://raw.githubusercontent.com/YOURUSER/pil0t/main"
INSTALL_DIR="/etc/pil0t"
DATA_DIR="/etc/pil0t/data"
STATIC_DIR="/etc/pil0t/static"
SERVICE_USER="$(whoami)"
VERSION="1.0.0"

# ── Colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
DIM='\033[2m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

header() { echo -e "\n${BOLD}${GREEN}▶ $1${NC}"; }
ok()     { echo -e "  ${GREEN}✓${NC} $1"; }
info()   { echo -e "  ${DIM}· $1${NC}"; }
err()    { echo -e "  ${RED}✗ $1${NC}"; exit 1; }

clear
echo -e "${GREEN}"
cat << 'EOF'
  ____  _ _     ___  _
 |  _ \(_) |   / _ \| |_
 | |_) | | |  | | | | __|
 |  __/| | |__| |_| | |_
 |_|   |_|_____\___/ \__|

EOF
echo -e "${NC}${DIM}  Raspberry Pi Management & Print Server${NC}"
echo -e "${DIM}  Version ${VERSION}${NC}\n"

# ── Check we're on a Pi ───────────────────────────────────────────────────────
header "Checking system"
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null && ! grep -qi "raspberry" /etc/os-release 2>/dev/null; then
    echo -e "  ${RED}Warning: This doesn't look like a Raspberry Pi.${NC}"
    read -p "  Continue anyway? [y/N] " -n 1 -r; echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && err "Aborted."
fi
ok "Raspberry Pi detected"

# ── Check for root/sudo ───────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    err "Please run with sudo: curl -fsSL $REPO/install.sh | sudo bash"
fi
ok "Running as root"

# ── Install dependencies ──────────────────────────────────────────────────────
header "Installing dependencies"
apt-get update -qq 2>/dev/null
ok "Package lists updated"

PACKAGES="python3 python3-pip python3-flask curl git"
for pkg in $PACKAGES; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        info "Installing $pkg..."
        apt-get install -y -qq "$pkg" 2>/dev/null
    fi
    ok "$pkg"
done

PIP_PACKAGES="flask flask-cors flask-sock evdev"
for pkg in $PIP_PACKAGES; do
    pip3 install "$pkg" --break-system-packages -q 2>/dev/null || \
    pip3 install "$pkg" -q 2>/dev/null
    ok "pip: $pkg"
done

# ── Create directories ────────────────────────────────────────────────────────
header "Creating directories"
mkdir -p "$INSTALL_DIR" "$DATA_DIR" "$STATIC_DIR"
ok "Created $INSTALL_DIR"
ok "Created $DATA_DIR"
ok "Created $STATIC_DIR"

# ── Download files ────────────────────────────────────────────────────────────
header "Downloading PiL0t files"

FILES="app.py print_sku.py"
for f in $FILES; do
    info "Downloading $f..."
    curl -fsSL "$REPO/$f" -o "$INSTALL_DIR/$f"
    ok "$f"
done

STATIC_FILES="index.html system.html filebrowser.html login.html"
for f in $STATIC_FILES; do
    info "Downloading static/$f..."
    curl -fsSL "$REPO/static/$f" -o "$STATIC_DIR/$f"
    ok "static/$f"
done

# ── Write version file ────────────────────────────────────────────────────────
echo "$VERSION" > "$INSTALL_DIR/version.txt"
ok "Version: $VERSION"

# ── Default data files ────────────────────────────────────────────────────────
header "Setting up default configuration"

# Only write defaults if files don't exist (preserve existing config on update)
[ ! -f "$DATA_DIR/printer_config.json" ] && cat > "$DATA_DIR/printer_config.json" << 'JSON'
{"printer_ip": "10.10.10.249", "printer_port": 9100}
JSON
ok "printer_config.json"

[ ! -f "$DATA_DIR/current_sku.txt" ] && echo "1490" > "$DATA_DIR/current_sku.txt"
ok "current_sku.txt (starting at 1490)"

[ ! -f "$DATA_DIR/branding.json" ] && cat > "$DATA_DIR/branding.json" << 'JSON'
{"title": "PiL0t", "subtitle": "PRINT SERVER"}
JSON
ok "branding.json"

[ ! -f "$DATA_DIR/auth_config.json" ] && cat > "$DATA_DIR/auth_config.json" << 'JSON'
{"guest_print": true, "protected": {"system": true, "files": true, "terminal": true}}
JSON
ok "auth_config.json"

# Default admin user (admin/admin) — password is SHA256 of "admin"
[ ! -f "$DATA_DIR/app_users.json" ] && cat > "$DATA_DIR/app_users.json" << 'JSON'
[{"username": "admin", "password": "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918", "role": "admin"}]
JSON
ok "app_users.json (admin/admin — change after first login)"

touch "$DATA_DIR/sku_log.txt"
ok "sku_log.txt"

# ── Permissions ───────────────────────────────────────────────────────────────
header "Setting permissions"
chown -R pi:pi "$INSTALL_DIR" 2>/dev/null || chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR"
chmod 600 "$DATA_DIR/app_users.json"
ok "Permissions set"

# ── Sudoers ───────────────────────────────────────────────────────────────────
header "Configuring sudoers"
SUDOERS_LINE="pi ALL=(ALL) NOPASSWD: /usr/bin/apt-get, /sbin/reboot, /sbin/shutdown, /bin/systemctl, /usr/bin/systemctl, /usr/bin/sysctl, /usr/sbin/iwlist, /usr/bin/ip, /sbin/ip, /bin/ip, /bin/cp, /bin/chmod, /usr/sbin/wpa_cli, /usr/bin/hostnamectl, /bin/sed, /usr/bin/tee, /usr/bin/rfkill, /sbin/iptables, /usr/sbin/wpa_supplicant, /usr/sbin/dhcpcd"
echo "$SUDOERS_LINE" > /etc/sudoers.d/pil0t
chmod 440 /etc/sudoers.d/pil0t
ok "Sudoers configured"

# ── Systemd services ──────────────────────────────────────────────────────────
header "Installing services"

curl -fsSL "$REPO/services/pil0t-web.service" -o /etc/systemd/system/pil0t-web.service
curl -fsSL "$REPO/services/pil0t-tracker.service" -o /etc/systemd/system/pil0t-tracker.service

# Fix username in service files
sed -i "s/User=pi/User=$SERVICE_USER/g" /etc/systemd/system/pil0t-web.service

systemctl daemon-reload
systemctl enable pil0t-web
systemctl enable pil0t-tracker
systemctl start pil0t-web
systemctl start pil0t-tracker 2>/dev/null || true  # tracker needs keypad plugged in
ok "pil0t-web service installed and started"
ok "pil0t-tracker service installed and enabled"

# ── Network boot script ───────────────────────────────────────────────────────
header "Installing network boot script"
curl -fsSL "$REPO/services/pil0t-network.sh" -o /etc/network/if-up.d/pil0t-network
chmod +x /etc/network/if-up.d/pil0t-network
ok "Network reconnect script installed"

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  PiL0t installed successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Get IP
IP=$(ip -4 addr show eth0 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
[ -z "$IP" ] && IP=$(ip -4 addr show wlan0 2>/dev/null | grep -oP '(?<=inet )\d+\.\d+\.\d+\.\d+' | head -1)
[ -z "$IP" ] && IP="<your-pi-ip>"

echo -e "  Open in browser:  ${BOLD}http://$IP:5000${NC}"
echo -e "  Default login:    ${BOLD}admin / admin${NC}"
echo -e "  Install location: ${BOLD}/etc/pil0t${NC}"
echo -e "  Data location:    ${BOLD}/etc/pil0t/data${NC}"
echo ""
echo -e "  ${DIM}Logs: sudo journalctl -u pil0t-web -f${NC}"
echo -e "  ${DIM}Stop: sudo systemctl stop pil0t-web${NC}"
echo ""
echo -e "  ${RED}${BOLD}Change the default admin password after first login!${NC}"
echo ""
