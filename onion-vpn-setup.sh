#!/bin/bash
# Onion-over-VPN Setup Script (WireGuard + Tor, iptables only)
# Verified working on Ubuntu 22.04 LTS
# Run as root on a public VPN server

# ========== Root Check ==========
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi

# ========== Install Dependencies ==========
apt update
apt install -y wireguard resolvconf tor netfilter-persistent iptables-persistent qrencode curl

# ========== WireGuard Configuration ==========
WG_PORT=51820
WG_INTERFACE="wg0"
SERVER_PUBLIC_IP=$(curl -4 -s ifconfig.me)
DEFAULT_IF=$(ip route list default | awk '{print $5}')

# Generate keys
mkdir -p /etc/wireguard
umask 077
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key

# Create WireGuard config (server)
cat > /etc/wireguard/$WG_INTERFACE.conf <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = $WG_PORT
PrivateKey = $(cat /etc/wireguard/private.key)
PostUp = iptables -A FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -A FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -A POSTROUTING -o $DEFAULT_IF -j MASQUERADE
PostDown = iptables -D FORWARD -i $WG_INTERFACE -j ACCEPT; iptables -D FORWARD -o $WG_INTERFACE -j ACCEPT; iptables -t nat -D POSTROUTING -o $DEFAULT_IF -j MASQUERADE
EOF

# Enable IP forwarding
echo 'net.ipv4.ip_forward=1' | tee -a /etc/sysctl.conf
sysctl -p

# Start WireGuard
systemctl enable --now wg-quick@$WG_INTERFACE

# ========== Tor Configuration ==========
cat > /etc/tor/torrc <<EOF
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 10.8.0.1:9040
DNSPort 10.8.0.1:5353
RunAsDaemon 1
ControlPort 127.0.0.1:9051
SocksPort 127.0.0.1:9050
CookieAuthentication 1
EOF

# Start Tor service
systemctl enable --now tor

# ========== iptables Rules for Onion-over-VPN ==========
# Flush old rules
iptables -F
iptables -t nat -F

# Allow loopback and established connections
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH (change port if needed)
iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow WireGuard
iptables -A INPUT -p udp --dport $WG_PORT -j ACCEPT
iptables -A OUTPUT -p udp --sport $WG_PORT -j ACCEPT

# Allow Tor outbound from server
iptables -A OUTPUT -p tcp --dport 9001:65535 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT

# Allow Tor control and DNS ports locally
iptables -A INPUT -p tcp --dport 9040 -s 10.8.0.0/24 -j ACCEPT
iptables -A INPUT -p udp --dport 5353 -s 10.8.0.0/24 -j ACCEPT

# Redirect all VPN client DNS and TCP traffic to Tor
iptables -t nat -A PREROUTING -i $WG_INTERFACE -p udp --dport 53 -j REDIRECT --to-ports 5353
iptables -t nat -A PREROUTING -i $WG_INTERFACE -p tcp --syn -j REDIRECT --to-ports 9040

# Block all non-Tor traffic from VPN clients (prevent leaks)
iptables -A FORWARD -i $WG_INTERFACE ! -o lo -p tcp --syn ! --dport 9040 -j REJECT
iptables -A FORWARD -i $WG_INTERFACE -p udp ! --dport 5353 -j REJECT

# Default policies: drop everything else
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Save iptables rules
netfilter-persistent save

# ========== Client Configuration ==========
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# Add client as peer to server config
cat >> /etc/wireguard/$WG_INTERFACE.conf <<EOF

# Client Configuration
[Peer]
PublicKey = $CLIENT_PUBLIC_KEY
AllowedIPs = 10.8.0.2/32
EOF

# Reload WireGuard configuration
wg syncconf wg0 <(wg-quick strip wg0)

# Generate client config
cat > /tmp/client.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = 10.8.0.2/24
DNS = 10.8.0.1

[Peer]
PublicKey = $(cat /etc/wireguard/public.key)
Endpoint = $SERVER_PUBLIC_IP:$WG_PORT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# ========== Verification ==========
echo "=============================================="
echo "SETUP COMPLETE!"
echo "=============================================="
echo "Server Status:"
echo "WireGuard: $(systemctl is-active wg-quick@$WG_INTERFACE)"
echo "Tor: $(systemctl is-active tor)"
echo ""
echo "Listening Ports:"
ss -tulnp | grep -E '51820|9040|5353'
echo ""
echo "Client Configuration:"
echo "Saved to /tmp/client.conf"
echo ""
echo "QR Code for mobile:"
qrencode -t ansiutf8 < /tmp/client.conf
echo "=============================================="
echo "To verify Tor routing on client:"
echo "1. Connect using client config"
echo "2. Run: curl -s https://check.torproject.org | grep -A 2 Congratulations"
echo "3. Should see: 'Congratulations. This browser is configured to use Tor'"
echo "=============================================="
