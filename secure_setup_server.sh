#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Script Configuration ---

# The new user to be created with sudo privileges.
NEW_USER="dev"

# The new SSH port. Choose a random port number between 1024 and 65535.
NEW_SSH_PORT="9322"

# The IP addresses allowed to connect to the new SSH port.
# Replace with your actual IP address(es). You can add more IPs separated by commas.
# To get your current public IP, you can run: curl ifconfig.me
ALLOWED_IPS="YOUR_IP_ADDRESS_HERE"

# --- Script Execution ---

echo "🚀 Starting server setup..."

# 1. Update and Upgrade System
echo "🔄 Updating and upgrading system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# 2. Create a New User
echo "👤 Creating a new user named '$NEW_USER'..."
sudo adduser --disabled-password --gecos "" $NEW_USER

# 3. Grant Root Privileges to the New User
echo " granting sudo access to '$NEW_USER'..."
sudo usermod -aG sudo $NEW_USER

# 4. Set Up SSH Key for the New User
echo "🔑 Setting up SSH key for '$NEW_USER'..."
sudo mkdir -p /home/$NEW_USER/.ssh
# IMPORTANT: Replace the public key below with your own public SSH key.
sudo echo "ssh-rsa YOUR_PUBLIC_SSH_KEY_HERE" > /home/$NEW_USER/.ssh/authorized_keys
sudo chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
sudo chmod 700 /home/$NEW_USER/.ssh
sudo chmod 600 /home/$NEW_USER/.ssh/authorized_keys

# 5. Secure SSH Configuration
echo "🔒 Securing SSH configuration..."
sudo sed -i "s/#Port 22/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/PermitRootLogin yes/PermitRootLogin no/" /etc/ssh/sshd_config
sudo sed -i "s/#PasswordAuthentication yes/PasswordAuthentication no/" /etc/ssh/sshd_config
sudo systemctl restart sshd

# 6. Configure UFW (Uncomplicated Firewall)
echo "🔥 Configuring UFW firewall..."
sudo ufw allow $NEW_SSH_PORT/tcp
sudo ufw allow http
sudo ufw allow https
# Allow SSH access only from specific IPs
for ip in $(echo $ALLOWED_IPS | sed "s/,/ /g")
do
    sudo ufw allow from $ip to any port $NEW_SSH_PORT proto tcp
done
sudo ufw --force enable

echo "✅ Server setup complete!"
echo "You can now log in as '$NEW_USER' using:"
echo "ssh $NEW_USER@your_server_ip -p $NEW_SSH_PORT"
