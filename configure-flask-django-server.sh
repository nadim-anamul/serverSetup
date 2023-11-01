#!/bin/bash

# Update system packages
sudo apt update

# Install Python and pip
sudo apt install -y python3 python3-pip

# Install uWSGI
sudo pip3 install uwsgi

# Install Nginx
sudo apt install -y nginx

# Ask for Python framework (Flask or Django)
read -p "Enter the Python framework you're using (flask/django): " python_framework

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask if HTTPS should be enabled
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Ask for project root directory
read -p "Enter the absolute path to your Python project root directory: " project_root

# Configure uWSGI
echo "[uwsgi]
module = wsgi:app

master = true
processes = 5

socket = /tmp/uwsgi_$domain_name.sock
chmod-socket = 660
vacuum = true" | sudo tee /etc/uwsgi/sites/$domain_name.ini > /dev/null

# Configure Nginx server block
echo "server {
    listen 80;
    server_name $domain_name;

    location = /favicon.ico { access_log off; log_not_found off; }
    location /static/ {
        root $project_root;
    }

    location / {
        include uwsgi_params;
        uwsgi_pass unix:/tmp/uwsgi_$domain_name.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}" | sudo tee /etc/nginx/sites-available/$domain_name > /dev/null

# Create a symbolic link to enable the site
sudo ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled

# Restart uWSGI
sudo systemctl restart uwsgi

# Restart Nginx
sudo systemctl restart nginx

# Enable HTTPS if requested
if [ "$enable_https" = "yes" ]; then
    sudo certbot --nginx -d $domain_name
fi

echo "Your server is now ready for hosting Python $python_framework applications. The site is accessible at http://$domain_name."
