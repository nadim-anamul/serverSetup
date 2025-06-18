#!/bin/bash

# --- Script Start ---

echo "🚀 Starting Nginx Installation and Performance Tuning (v4 - Robust Install)..."

# Update system packages
sudo apt update

# Install or Reinstall Nginx.
# Using --reinstall ensures that if Nginx is in a broken state (e.g., missing
# config files), it will be fixed by restoring the default files.
echo "🔧 Installing/Reinstalling Nginx to ensure default files exist..."
sudo apt install --reinstall -y nginx

# --- Configure Global Directives in the main nginx.conf file ---
echo "🔧 Applying global settings to /etc/nginx/nginx.conf..."

# Set worker_processes to auto-detect CPU cores
sudo sed -i 's/worker_processes .*/worker_processes auto;/' /etc/nginx/nginx.conf

# Set worker_connections in the events block
sudo sed -i 's/worker_connections .*/    worker_connections 4096;/' /etc/nginx/nginx.conf

# Comment out the default 'gzip on;' directive to prevent conflicts.
echo "🔧 Neutralizing default Gzip setting to avoid duplicates..."
sudo sed -i 's/^\s*gzip on;/    # &/' /etc/nginx/nginx.conf

# --- Create a Custom HTTP-level Performance Configuration File ---
echo "🔧 Creating custom HTTP-level performance configuration..."
sudo bash -c "cat > /etc/nginx/conf.d/00-performance-tuning.conf" <<'EOF'
# --- General HTTP Performance Settings ---
keepalive_timeout 65;
keepalive_requests 10000;
server_tokens off;
client_body_buffer_size 128k;
client_header_buffer_size 16k;
client_max_body_size 100M;

# --- Gzip Compression Settings ---
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 5;
gzip_min_length 256;
gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/vcard
    text/vnd.rim.location.xloc
    text/vtt
    text/x-component
    text/x-cross-domain-policy;

# --- Static Asset Caching ---
map $sent_http_content_type $expires {
    "text/css"                                      max;
    "application/javascript"                        max;
    "image/jpeg"                                    max;
    "image/png"                                     max;
    "image/gif"                                     max;
    "image/svg+xml"                                 max;
    "application/font-woff"                         max;
    "application/font-woff2"                        max;
    "application/vnd.ms-fontobject"                 max;
    "application/x-font-ttf"                        max;
    "font/opentype"                                 max;
    default                                         off;
}
EOF

# --- Modify the Default Server Block to use new settings ---
DEFAULT_SITE_CONF="/etc/nginx/sites-available/default"
echo "⚙️  Applying optimizations to the default server block..."

# Create a backup of the original default site configuration
[ ! -f "$DEFAULT_SITE_CONF.bak" ] && sudo cp $DEFAULT_SITE_CONF $DEFAULT_SITE_CONF.bak

# Enable HTTP/2 on listen directives
sudo sed -i 's/listen 80 default_server;/listen 80 default_server http2;/g' $DEFAULT_SITE_CONF
sudo sed -i 's/listen \[::\]:80 default_server;/listen \[::\]:80 default_server http2;/g' $DEFAULT_SITE_CONF

# Add the expires directive to the server block
grep -q "expires \$expires;" "$DEFAULT_SITE_CONF" || sudo sed -i '/server_name _;/a \    expires $expires;' $DEFAULT_SITE_CONF

# --- Firewall Configuration ---
echo "🔒 Configuring Firewall (UFW)..."
sudo ufw allow 'Nginx Full'
sudo ufw allow 'OpenSSH'
sudo ufw --force enable

# --- Final Steps ---
echo "✅ Validating Nginx configuration..."
sudo nginx -t

# If the test is successful, restart Nginx
if [ $? -eq 0 ]; then
    echo "🔄 Restarting Nginx to apply all changes..."
    sudo systemctl restart nginx
    sudo systemctl enable nginx
    echo "🎉 Nginx has been installed and tuned for better performance."
else
    echo "❌ Nginx configuration test failed. Please review the errors above. Nginx was not restarted."
fi
