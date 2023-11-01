#!/bin/bash

# Update system packages
sudo apt update

# Install software-properties-common for managing PPAs
sudo apt install -y software-properties-common

# Add Ondrej PHP repository
sudo add-apt-repository ppa:ondrej/php

# Update system packages after adding the repository
sudo apt update

# Install PHP 7.4, 8.0, 8.1, and 8.2
sudo apt install -y php7.4 php7.4-cli php7.4-fpm php7.4-mysql php7.4-gd php7.4-mbstring php7.4-curl php7.4-xml php7.4-zip
sudo apt install -y php8.0 php8.0-cli php8.0-fpm php8.0-mysql php8.0-gd php8.0-mbstring php8.0-curl php8.0-xml php8.0-zip
sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-gd php8.1-mbstring php8.1-curl php8.1-xml php8.1-zip
sudo apt install -y php8.2 php8.2-cli php8.2-fpm php8.2-mysql php8.2-gd php8.2-mbstring php8.2-curl php8.2-xml php8.2-zip

# Set PHP 8.2 as the active version
sudo update-alternatives --set php /usr/bin/php8.2

# Inform the user about the completion of the installation
echo "PHP 7.4, 8.0, 8.1, and 8.2 have been installed. PHP 8.2 is set as the active version."

# Provide the command to change PHP version
echo "To change PHP version in the future, run the following command:"
echo "sudo update-alternatives --config php"
