#!/bin/bash

# === CONFIG ===
NEW_PORT=9322
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
IPTABLES_RULES_FILE="/etc/iptables/rules.v4"

echo "[+] Changing SSH port to $NEW_PORT..."

# === Backup SSH config ===
cp "$SSH_CONFIG_FILE" "${SSH_CONFIG_FILE}.bak"

# === Set new port ===
sed -i "s/^#Port .*/Port $NEW_PORT/" "$SSH_CONFIG_FILE"
sed -i "s/^Port .*/Port $NEW_PORT/" "$SSH_CONFIG_FILE"
if ! grep -q "^Port $NEW_PORT" "$SSH_CONFIG_FILE"; then
    echo "Port $NEW_PORT" >> "$SSH_CONFIG_FILE"
fi

# === Check sshd_config.d overrides ===
if grep -r "^Port " /etc/ssh/sshd_config.d/ &>/dev/null; then
    echo "[!] Warning: SSH port override found in sshd_config.d. Please check manually."
fi

# === Allow new port via iptables ===
echo "[+] Adding iptables rule for port $NEW_PORT..."
iptables -I INPUT -p tcp --dport "$NEW_PORT" -j ACCEPT

# === Block old port (22) ===
iptables -A INPUT -p tcp --dport 22 -j DROP

# === Save iptables rules manually ===
echo "[+] Saving iptables rules..."
mkdir -p /etc/iptables
iptables-save > "$IPTABLES_RULES_FILE"

# === Ensure rules are restored on boot ===
if ! grep -q "iptables-restore" /etc/rc.local 2>/dev/null; then
    echo "[+] Setting up iptables restore on boot..."
    if [ ! -f /etc/rc.local ]; then
        echo -e "#!/bin/bash\nexit 0" > /etc/rc.local
        chmod +x /etc/rc.local
    fi
    sed -i '/^exit 0/i iptables-restore < /etc/iptables/rules.v4' /etc/rc.local
fi

# === Test sshd config ===
echo "[+] Testing SSH config..."
if sshd -t; then
    echo "[+] SSH config is valid."
else
    echo "[!] SSH config has errors! Restoring backup..."
    cp "${SSH_CONFIG_FILE}.bak" "$SSH_CONFIG_FILE"
    exit 1
fi

# === Restart SSH service ===
echo "[+] Restarting SSH service..."
systemctl restart ssh

# === Final check ===
echo "[+] SSH should now be listening on port $NEW_PORT:"
ss -tulpn | grep ssh

echo "[✔] Done. DO NOT CLOSE this terminal until you’ve tested SSH on the new port:"
echo "    ssh -p $NEW_PORT youruser@yourserver"

# === Optional Reboot Prompt ===
read -p "[?] Reboot now to ensure all changes apply? (y/N): " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "[+] Rebooting system..."
    reboot
else
    echo "[+] Reboot skipped. Make sure to reboot manually later if issues persist."
fi
