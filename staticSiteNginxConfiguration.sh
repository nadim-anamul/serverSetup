#!/bin/bash

# Ask for the project folder name
read -p "Enter the project folder name (e.g., mysite): " project_folder

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask if HTTPS should be enabled
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Set project root directory based on provided folder name
project_root="/var/www/html/$project_folder"

# Nginx configuration file path (based on domain name)
nginx_config="/etc/nginx/sites-available/$domain_name.conf"

# Create Nginx configuration file
echo "server {
    listen 80;
    server_name $domain_name;
    root $project_root;

    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ /\.ht {
        deny all;
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

echo "Nginx configuration for $domain_name has been created. Your static HTML site is now accessible at http://$domain_name."
