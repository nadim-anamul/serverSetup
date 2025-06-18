#!/bin/bash

# --- Configuration Variables ---
CLIENT_MAX_BODY_SIZE="100M"
KEEPALIVE_TIMEOUT="65"
WORKER_CONNECTIONS="4096"

# --- Script Start ---

echo "🚀 Starting Nginx Installation and Performance Tuning..."

# Update system packages
sudo apt update

# Install Nginx
sudo apt install -y nginx

# --- Create a Custom Performance Configuration File ---
# This is better than editing nginx.conf directly.
echo "🔧 Creating custom Nginx performance configuration..."
sudo bash -c "cat > /etc/nginx/conf.d/00-performance-tuning.conf" <<'EOF'
# --- General Performance Settings ---

# Auto-detect the number of CPU cores for worker processes
worker_processes auto;

# Set the max number of connections per worker process
# (worker_processes * worker_connections = max clients)
worker_connections 4096;

# Keepalive connections timeout
keepalive_timeout 65;
keepalive_requests 10000;

# Hide Nginx version for security
server_tokens off;

# Optimize buffer sizes
client_body_buffer_size 128k;
client_header_buffer_size 16k;

# Set client_max_body_size (useful for file uploads)
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
# Add a 'expires' map to control caching based on file type.
# This should be placed in the main http block.
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
# This enables HTTP/2 and applies the expires map for caching.
DEFAULT_SITE_CONF="/etc/nginx/sites-available/default"

echo "⚙️  Applying optimizations to the default server block..."

# Create a backup of the original default site configuration
sudo cp $DEFAULT_SITE_CONF $DEFAULT_SITE_CONF.bak

# Enable HTTP/2 on listen directives for both IPv4 and IPv6
sudo sed -i 's/listen 80 default_server;/listen 80 default_server http2;/g' $DEFAULT_SITE_CONF
sudo sed -i 's/listen \[::\]:80 default_server;/listen \[::\]:80 default_server http2;/g' $DEFAULT_SITE_CONF

# Add the expires directive to the server block
sudo sed -i '/server_name _;/a \    expires $expires;' $DEFAULT_SITE_CONF


# --- Firewall Configuration ---
echo "🔒 Configuring Firewall (UFW)..."
sudo ufw allow 'Nginx Full' # Allows both HTTP and HTTPS
sudo ufw allow 'OpenSSH'
sudo ufw --force enable

# --- Final Steps ---
echo "✅ Validating Nginx configuration..."
# Test the configuration for syntax errors before applying
sudo nginx -t

echo "🔄 Restarting Nginx to apply all changes..."
sudo systemctl restart nginx
sudo systemctl enable nginx

echo "🎉 Nginx has been installed and tuned for better performance."
echo "You can access your server via its IP address in a web browser."
echo "Firewall is active and allows HTTP, HTTPS, and SSH traffic."
