#!/bin/bash

# Update system packages
sudo apt update

# Install prerequisites to use repositories over HTTPS
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg

# Add Docker GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update system packages again after adding Docker repository
sudo apt update

# Install Docker and additional packages
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker to start on boot
sudo systemctl start docker
sudo systemctl enable docker

# Inform the user about the completion of the process
echo "Docker and additional packages have been installed and started. You can now use Docker on your server."
