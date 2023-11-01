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
echo "server {
    listen 80;
    server_name $domain_name;
    
    location / {
        proxy_pass http://localhost:$local_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}" | sudo tee $nginx_config > /dev/null

# Create a symbolic link to enable the site
sudo ln -s $nginx_config /etc/nginx/sites-enabled/

# Restart Nginx
sudo systemctl restart nginx

# Enable HTTPS if requested
if [ "$enable_https" = "yes" ]; then
    sudo certbot --nginx -d $domain_name
fi

echo "Nginx configuration for $domain_name has been created and the site is now live."
