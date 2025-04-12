#!/bin/bash

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask for local running port number
read -p "Enter the local port number where your Docker container is running (e.g., 3000): " local_port

# Ask if the site should be served over HTTPS
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Nginx configuration file path
nginx_config="/etc/nginx/sites-available/$domain_name.conf"

# Create Nginx configuration file
echo "Creating Nginx config at $nginx_config..."
sudo bash -c "cat > $nginx_config" <<EOF
server {
    listen 80;
    server_name $domain_name;

    location / {
        proxy_pass http://127.0.0.1:$local_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Create symbolic link if it doesn't already exist
if [ ! -L "/etc/nginx/sites-enabled/$domain_name.conf" ]; then
    sudo ln -s $nginx_config /etc/nginx/sites-enabled/
fi

# Restart Nginx
echo "Restarting Nginx..."
sudo systemctl restart nginx

# Enable HTTPS if requested
if [ "$enable_https" = "yes" ]; then
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        echo "Certbot not found. Installing..."
        sudo apt update
        sudo apt install -y software-properties-common
        sudo add-apt-repository universe -y
        sudo add-apt-repository ppa:certbot/certbot -y
        sudo apt update
        sudo apt install -y certbot python3-certbot-nginx
    fi

    # Obtain and configure SSL certificate
    echo "Running Certbot for domain $domain_name..."
    sudo certbot --nginx -d "$domain_name"
fi

echo "Nginx configuration for $domain_name has been created and the site is now live."
