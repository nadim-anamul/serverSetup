#!/bin/bash

# Ask for domain name
read -p "Enter your domain name (e.g., example.com): " domain_name

# Ask for local running port number
read -p "Enter the local port number where your Docker container is running (e.g., 3000): " local_port

# Ask if the site should be served over HTTPS
read -p "Do you want to enable HTTPS for the site? (yes/no): " enable_https

# Ask for the HTTP Authorization token
read -p "Enter the HTTP Authorization token: " http_authorization

# Sanitize domain name to use as a folder name
safe_domain_name=$(echo "$domain_name" | tr -cd 'a-zA-Z0-9._-')

# Define cache folder and key zone based on the sanitized domain name
cache_folder="/var/lib/nginx/${safe_domain_name}/cache"
cache_key_zone="${safe_domain_name}_cache"


# Ensure the cache folder exists
sudo mkdir -p "$cache_folder"
sudo chown -R www-data:www-data "$cache_folder"
sudo chmod -R 755 "$cache_folder"

# Nginx configuration file path
nginx_config="/etc/nginx/sites-available/$domain_name.conf"

# Create Nginx configuration file
echo "proxy_cache_path $cache_folder levels=1:2 keys_zone=$cache_key_zone:50m max_size=5g inactive=180m use_temp_path=off;
server {
    listen 80;

    server_name $domain_name;

    location / {
        if ($http_authorization != \"$http_authorization\") {
            return 403;
        }

        # Proxy cache configuration
        proxy_cache $cache_key_zone;
        add_header X-Proxy-Cache $upstream_cache_status;
        proxy_cache_valid 200 1d;
        proxy_ignore_headers Set-Cookie;

        proxy_pass_request_headers on;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_redirect off;
        proxy_pass http://127.0.0.1:$local_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';

        proxy_cache_use_stale error timeout http_500 http_502 http_503 http_504 http_429;
    }
}" | sudo tee "$nginx_config" > /dev/null

# Create a symbolic link to enable the site
sudo ln -sf "$nginx_config" /etc/nginx/sites-enabled/

# Test Nginx configuration
if ! sudo nginx -t; then
    echo "Nginx configuration test failed. Please check your configuration."
    exit 1
fi

# Restart Nginx
sudo systemctl restart nginx

# Enable HTTPS if requested
if [ "$enable_https" = "yes" ]; then
    sudo certbot --nginx -d "$domain_name"
    if [ $? -ne 0 ]; then
        echo "Failed to enable HTTPS. Please check Certbot logs for more details."
        exit 1
    fi
fi

echo "Nginx configuration for $domain_name has been created and the site is now live."
