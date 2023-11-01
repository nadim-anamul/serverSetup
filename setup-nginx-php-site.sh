#!/bin/bash

# Ask for PHP version
read -p "Enter the PHP version for your project (e.g., 7.4, 8.0, 8.1, 8.2): " php_version

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask if HTTPS should be enabled
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Ask for project root directory
read -p "Enter the absolute path to your PHP project root directory: " project_root

# Nginx configuration file path (based on domain name)
nginx_config="/etc/nginx/sites-available/$domain_name.conf"

# Create Nginx configuration file
echo "server {
    listen 80;
    server_name $domain_name;
    root $project_root;

    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php$php_version-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
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

echo "Nginx configuration for $domain_name has been created. Your PHP project is now accessible at http://$domain_name."
