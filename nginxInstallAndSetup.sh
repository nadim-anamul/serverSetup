#!/bin/bash

# Update system packages
sudo apt update

# Install Nginx
sudo apt install -y nginx

# Add client_max_body_size to the default Nginx configuration
sudo sed -i '/http {/a \        client_max_body_size 100M;' /etc/nginx/nginx.conf

# Start Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Configure UFW (Uncomplicated Firewall) to allow HTTP traffic
sudo ufw allow 'Nginx HTTP'

# Optionally, you can open the HTTPS port if you plan to use SSL/TLS
# sudo ufw allow 'Nginx HTTPS'

# Allow SSH connections
sudo ufw allow ssh

# Enable UFW
# The script will prompt for confirmation here.
sudo ufw --force enable

# Restart Nginx to apply the new configuration
sudo systemctl restart nginx

# Inform the user about the completion of the process
echo "Nginx has been installed and configured with a client_max_body_size of 100M."
echo "You can access your server via its IP address in a web browser."
echo "SSH access has also been allowed through the firewall."
