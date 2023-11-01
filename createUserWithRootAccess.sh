#!/bin/bash

# Prompt for username
read -p "Enter the username: " USERNAME

# Prompt for password (will not be visible during input)
read -s -p "Enter the password: " PASSWORD

# Create a user with a password and grant sudo access
sudo useradd -m $USERNAME
echo "$USERNAME:$PASSWORD" | sudo chpasswd
sudo usermod -aG sudo $USERNAME

# Inform the user about the completion of the process
echo "User $USERNAME has been created with sudo access."

