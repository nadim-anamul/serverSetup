#!/bin/bash

# === CONFIG ===
NEW_PORT=9322
SSH_CONFIG_FILE="/etc/ssh/sshd_config"
IPTABLES_SAVE_CMD="netfilter-persistent save"

echo "[+] Changing SSH port to $NEW_PORT..."

# === Backup SSH config ===
cp $SSH_CONFIG_FILE ${SSH_CONFIG_FILE}.bak

# === Set new port ===
sed -i "s/^#Port .*/Port $NEW_PORT/" $SSH_CONFIG_FILE
sed -i "s/^Port .*/Port $NEW_PORT/" $SSH_CONFIG_FILE
if ! grep -q "^Port $NEW_PORT" $SSH_CONFIG_FILE; then
    echo "Port $NEW_PORT" >> $SSH_CONFIG_FILE
fi

# === Ensure port is not overridden ===
if grep -r "^Port " /etc/ssh/sshd_config.d/ &>/dev/null; then
    echo "[!] Warning: SSH port override found in sshd_config.d. Please check manually."
fi

# === Allow new port via iptables ===
echo "[+] Adding iptables rule for port $NEW_PORT..."
iptables -I INPUT -p tcp --dport $NEW_PORT -j ACCEPT

# === Drop old port (22) ===
iptables -A INPUT -p tcp --dport 22 -j DROP

# === Save iptables rules ===
echo "[+] Installing iptables-persistent (if not present)..."
DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent
$IPTABLES_SAVE_CMD

# === Test sshd config ===
echo "[+] Testing SSH config..."
if sshd -t; then
    echo "[+] SSH config is valid."
else
    echo "[!] SSH config has errors! Restoring backup..."
    cp ${SSH_CONFIG_FILE}.bak $SSH_CONFIG_FILE
    exit 1
fi

# === Restart SSH service ===
echo "[+] Restarting SSH service..."
systemctl restart ssh

# === Final test ===
echo "[+] SSH should now be listening on port $NEW_PORT"
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
