#!/bin/bash

# Update system packages
sudo apt update

# Install Nginx
sudo apt install -y nginx

# Start Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Configure UFW (Uncomplicated Firewall) to allow HTTP traffic
sudo ufw allow 'Nginx HTTP'

# Optionally, you can open the HTTPS port if you plan to use SSL/TLS
# sudo ufw allow 'Nginx HTTPS'

# Enable UFW
sudo ufw enable

# Inform the user about the completion of the process
echo "Nginx has been installed and configured. You can access your server via its IP address in a web browser."
