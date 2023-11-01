#!/bin/bash

# Ask for Python version
read -p "Enter the Python version for your project (e.g., 3.8, 3.9, 3.10): " python_version

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask if HTTPS should be enabled
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Ask for project root directory
read -p "Enter the absolute path to your Python project root directory: " project_root

# Nginx configuration file path (based on domain name)
nginx_config="/etc/nginx/sites-available/$domain_name.conf"

# Create Nginx configuration file
echo "server {
    listen 80;
    server_name $domain_name;
    root $project_root;

    location / {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/uwsgi_$domain_name.sock;
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

echo "Nginx configuration for $domain_name has been created. Your Python project is now accessible at http://$domain_name."
