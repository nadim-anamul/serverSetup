#!/bin/bash

# Update system packages
sudo apt update

# Install Git
sudo apt install -y git

# Install MongoDB
sudo apt install -y mongodb

# Install MySQL
sudo apt install -y mysql-server

# Start and enable MongoDB to start on boot
sudo systemctl start mongodb
sudo systemctl enable mongodb

# Start and enable MySQL to start on boot
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure MySQL installation (set root password and remove anonymous users, disallow root login remotely, remove test database)
sudo mysql_secure_installation

# Inform the user about the completion of the process
echo "Git, MongoDB, and MySQL have been installed. MongoDB and MySQL services have been started and enabled."
