#!/bin/bash
set -e

# Server will automatically block SSH brute force attacks
# Root login will be disabled
# Only your new user with SSH key can login
# Unattended upgrades will keep system patched
# Idle users auto-logout after 15 minutes
# Test the new SSH connection (ssh -p 9322 youruser@your-server) in a new terminal before you logout from root.

# === CONFIG ===
NEW_SSH_PORT=9322
NEW_USERNAME="youruser"   # CHANGE THIS
PUB_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM.... your@email.com"   # CHANGE THIS to your real public key

# === Create new user ===
if id "$NEW_USERNAME" &>/dev/null; then
    echo "[+] User $NEW_USERNAME already exists, skipping creation."
else
    echo "[+] Creating new user: $NEW_USERNAME"
    adduser --disabled-password --gecos "" $NEW_USERNAME
    usermod -aG sudo $NEW_USERNAME
fi

# === Setup SSH key authentication ===
echo "[+] Setting up SSH key for $NEW_USERNAME"
mkdir -p /home/$NEW_USERNAME/.ssh
echo "$PUB_SSH_KEY" > /home/$NEW_USERNAME/.ssh/authorized_keys
chmod 700 /home/$NEW_USERNAME/.ssh
chmod 600 /home/$NEW_USERNAME/.ssh/authorized_keys
chown -R $NEW_USERNAME:$NEW_USERNAME /home/$NEW_USERNAME/.ssh

# === Update system ===
echo "[+] Updating system..."
apt update && apt upgrade -y

# === Install security packages ===
echo "[+] Installing security packages..."
apt install -y fail2ban ufw unattended-upgrades sudo

# === Harden SSH config ===
echo "[+] Configuring SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

sed -i "s/^#Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sed -i "s/^Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Make sure AllowUsers is set properly
if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
    sed -i "s/^AllowUsers .*/AllowUsers $NEW_USERNAME/" /etc/ssh/sshd_config
else
    echo "AllowUsers $NEW_USERNAME" >> /etc/ssh/sshd_config
fi

# === Setup UFW Firewall ===
echo "[+] Configuring UFW firewall..."
ufw default deny incoming
ufw default allow outgoing
ufw allow "$NEW_SSH_PORT"/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable

# === Enable Unattended Upgrades ===
echo "[+] Enabling automatic security updates..."
dpkg-reconfigure -f noninteractive unattended-upgrades

# === Configure idle timeout logout (15 min) ===
echo "[+] Setting idle logout timeout..."
echo "TMOUT=900" > /etc/profile.d/timeout.sh
echo "readonly TMOUT" >> /etc/profile.d/timeout.sh
echo "export TMOUT" >> /etc/profile.d/timeout.sh

# === Enable and Start Fail2Ban ===
echo "[+] Enabling Fail2Ban..."
systemctl enable fail2ban
systemctl start fail2ban

# === Restart SSH service ===
echo "[+] Restarting SSH service..."
systemctl restart ssh

# === Final info ===
echo "[✔] Hardening complete!"
echo "Test your new SSH connection first before closing:"
echo "    ssh -p $NEW_SSH_PORT $NEW_USERNAME@your-server-ip"
