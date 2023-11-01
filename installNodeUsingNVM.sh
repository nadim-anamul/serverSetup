#!/bin/bash

# Install NVM (Node Version Manager)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash

# Load NVM in the current shell session
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# Show available Node.js versions using NVM
echo "Available Node.js versions:"
nvm list

# Prompt the user to enter the desired Node.js version number
read -p "Enter the desired Node.js version number from the list above: " desired_node_version

# Install the specified Node.js version using NVM
nvm install $desired_node_version

# Set the installed Node.js version as the default
nvm alias default $desired_node_version

# Inform the user about the completion of the process
echo "Node.js version $desired_node_version has been installed and set as the default version using NVM."
