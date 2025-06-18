#!/bin/bash

# =================================================================================
# =      Ultimate Nginx Reverse Proxy Site Setup Script (Flexible Domain)         =
# =================================================================================
# = This script will:                                                             =
# = 1. Ask for your desired domain setup (non-www, www, or both).                 =
# = 2. Dynamically configure Nginx and Certbot based on your choice.              =
# = 3. Securely request certificates for only the domains you need.               =
# = 4. Verify the Certbot auto-renewal timer.                                     =
# =================================================================================

echo "--- Nginx Site Setup ---"

# --- One-Time Global Optimal Setup ---
GLOBAL_CONFIG="/etc/nginx/conf.d/00-global-tuning.conf"
if [ ! -f "$GLOBAL_CONFIG" ]; then
    echo "🔧 First-time setup: Applying optimal global Nginx settings..."
    sudo sed -i 's/worker_processes .*/worker_processes auto;/' /etc/nginx/nginx.conf
    sudo sed -i 's/worker_connections .*/    worker_connections 4096;/' /etc/nginx/nginx.conf
    sudo sed -i 's/^\s*gzip on;/    # &/' /etc/nginx/nginx.conf
    sudo bash -c "cat > $GLOBAL_CONFIG" <<'EOF'
# --- Global Performance & Security Settings ---
keepalive_timeout 65;
keepalive_requests 10000;
server_tokens off;
client_body_buffer_size 128k;
client_header_buffer_size 16k;
# --- Gzip Compression Settings ---
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_min_length 256;
gzip_types
    application/atom+xml application/javascript application/json application/rss+xml
    application/vnd.ms-fontobject application/x-font-ttf application/xhtml+xml
    application/xml font/opentype image/svg+xml image/x-icon text/css
    text/plain text/x-component;
EOF
    echo "✅ Global settings applied."
else
    echo "✅ Global settings already exist. Skipping."
fi
echo ""

# --- User Input ---
read -p "Enter your base domain name (e.g., myapp.com): " base_domain

echo "Which version of the domain do you want to set up?"
echo "  1) $base_domain (non-www ONLY)"
echo "  2) www.$base_domain (www ONLY)"
echo "  3) Both (redirects the non-primary version to the primary one)"
read -p "Enter choice (1, 2, or 3): " setup_choice

read -p "Enter the local port your app is running on (e.g., 3000): " local_port
read -p "Enable HTTP/2? (yes/no): " enable_http2
read -p "Enable HTTPS with Certbot (Let's Encrypt)? (yes/no): " enable_https

# Validate input
if [ -z "$base_domain" ] || [ -z "$local_port" ]; then
    echo "❌ Base domain and local port cannot be empty. Aborting."
    exit 1
fi

# --- Dynamic Configuration Variables ---
http2_directive=""
if [ "$enable_http2" = "yes" ]; then
    http2_directive=" http2"
fi

# Use a 'case' statement to handle the setup choice
case "$setup_choice" in
    1) # Configure for non-www ONLY
        primary_domain="$base_domain"
        server_name_line="server_name $primary_domain;"
        redirect_block=""
        certbot_domains_args="-d $primary_domain"
        ;;
    2) # Configure for www ONLY
        primary_domain="www.$base_domain"
        server_name_line="server_name $primary_domain;"
        redirect_block=""
        certbot_domains_args="-d $primary_domain"
        ;;
    3) # Configure for BOTH with a redirect
        echo "You chose to set up both. Which version should be primary?"
        echo "  1) $base_domain (redirects www.$base_domain)"
        echo "  2) www.$base_domain (redirects $base_domain)"
        read -p "Enter redirect choice (1 or 2): " redirect_choice

        if [ "$redirect_choice" = "1" ]; then
            primary_domain="$base_domain"
            redirect_domain="www.$base_domain"
        elif [ "$redirect_choice" = "2" ]; then
            primary_domain="www.$base_domain"
            redirect_domain="$base_domain"
        else
            echo "❌ Invalid redirect choice. Aborting."
            exit 1
        fi

        server_name_line="server_name $primary_domain;"
        # Certificate must cover BOTH domains for a clean redirect without SSL errors
        certbot_domains_args="-d $primary_domain -d $redirect_domain"
        redirect_block=$(cat <<EOF

# Redirect the non-primary domain to the primary one
server {
    listen 80$http2_directive;
    server_name $redirect_domain;
    return 301 \$scheme://$primary_domain\$request_uri;
}
EOF
)
        ;;
    *)
        echo "❌ Invalid choice. Please enter 1, 2, or 3. Aborting."
        exit 1
        ;;
esac

# --- Nginx Configuration ---
nginx_config="/etc/nginx/sites-available/$base_domain.conf"
echo ""
echo "--- Configuring Nginx ---"
echo "✅ Primary Domain/Server Name: $primary_domain"
[ -n "$redirect_domain" ] && echo "✅ Redirects From: $redirect_domain"
echo "Creating Nginx config at $nginx_config..."

sudo bash -c "cat > $nginx_config" <<EOF
# Main configuration for the site
server {
    listen 80$http2_directive;
    $server_name_line

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    # Certbot challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    # Reverse proxy to the application
    location / {
        proxy_pass http://127.0.0.1:$local_port;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
$redirect_block
EOF

# --- Enable Site and Restart Nginx ---
if [ ! -L "/etc/nginx/sites-enabled/$base_domain.conf" ]; then
    sudo ln -s "$nginx_config" "/etc/nginx/sites-enabled/"
    echo "✅ Site enabled."
else
    echo "✅ Site already enabled."
fi

echo "Validating Nginx configuration..."
sudo nginx -t

if [ $? -eq 0 ]; then
    echo "✅ Configuration is valid. Restarting Nginx..."
    sudo systemctl restart nginx
else
    echo "❌ Nginx configuration test failed. Nginx was not restarted."
    exit 1
fi

# --- HTTPS with Certbot ---
if [ "$enable_https" = "yes" ]; then
    echo ""
    echo "--- Setting up HTTPS with Certbot ---"
    if ! command -v certbot &> /dev/null; then
        echo "Certbot not found. Installing..."
        sudo apt-get update
        sudo apt-get install -y certbot python3-certbot-nginx
    fi

    # Use the dynamically created domain arguments for the cert request
    echo "Running Certbot with domains: $certbot_domains_args"
    sudo certbot --nginx $certbot_domains_args --redirect --agree-tos --no-eff-email -m "admin@$base_domain"

    # --- Verify Auto-Renewal ---
    echo ""
    echo "--- Verifying Certificate Auto-Renewal ---"
    echo "Certbot automatically creates a systemd timer for renewal."
    
    if systemctl list-timers | grep -q 'certbot'; then
        echo "✅ Certbot timer is active."
        sudo systemctl list-timers | grep 'certbot'
    else
        echo "⚠️  Could not find Certbot timer. Automatic renewal might not be configured."
    fi

    echo "Performing a dry run of the renewal process to confirm it works..."
    sudo certbot renew --dry-run
fi

echo ""
echo "🎉 Success! Nginx configuration for your site is complete and live."
