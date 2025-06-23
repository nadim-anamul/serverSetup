#!/bin/bash

# ##################################################################
# WireGuard Double-Hop VPN Configuration Generator
# ##################################################################
# This script generates all necessary configuration files for a
# double-hop WireGuard setup involving a client, an entry server (A),
# and an exit server (B).

set -e
echo "--- WireGuard Double-Hop VPN Config Generator ---"

# --- 1. GATHER USER INPUT ---
read -p "Enter Public IP for Server A (Entry Node): " SERVER_A_PUBLIC_IP
read -p "Enter Public IP for Server B (Exit Node): " SERVER_B_PUBLIC_IP
read -p "Enter Public Interface for Server A (e.g., eth0): " SERVER_A_MAIN_IFACE
read -p "Enter Public Interface for Server B (e.g., eth0): " SERVER_B_MAIN_IFACE
read -p "Enter WireGuard Port (e.g., 51820): " WG_PORT

# Define subnets - these can be customized if needed
WG_TUNNEL_1_SUBNET="10.100.1.0/24"
SERVER_A_TUNNEL_1_IP="10.100.1.1"
CLIENT_TUNNEL_1_IP="10.100.1.10"

WG_TUNNEL_2_SUBNET="10.100.2.0/24"
SERVER_A_TUNNEL_2_IP="10.100.2.2"
SERVER_B_TUNNEL_2_IP="10.100.2.1"

# --- 2. PREPARE DIRECTORIES AND KEYS ---
echo "[+] Creating output directory and generating keys..."
OUTPUT_DIR="double_vpn_configs"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"/{server_a,server_b,client}

umask 077
# Server A Keys
wg genkey | tee "$OUTPUT_DIR/server_a/private.key" | wg pubkey > "$OUTPUT_DIR/server_a/public.key"
# Server B Keys
wg genkey | tee "$OUTPUT_DIR/server_b/private.key" | wg pubkey > "$OUTPUT_DIR/server_b/public.key"
# Client Keys
wg genkey | tee "$OUTPUT_DIR/client/private.key" | wg pubkey > "$OUTPUT_DIR/client/public.key"

# Read keys into variables
SERVER_A_PRIV_KEY=$(cat "$OUTPUT_DIR/server_a/private.key")
SERVER_A_PUB_KEY=$(cat "$OUTPUT_DIR/server_a/public.key")
SERVER_B_PRIV_KEY=$(cat "$OUTPUT_DIR/server_b/private.key")
SERVER_B_PUB_KEY=$(cat "$OUTPUT_DIR/server_b/public.key")
CLIENT_PRIV_KEY=$(cat "$OUTPUT_DIR/client/private.key")
CLIENT_PUB_KEY=$(cat "$OUTPUT_DIR/client/public.key")

# --- 3. GENERATE CONFIGURATION FILES ---

# == SERVER B (EXIT NODE) CONFIG ==
echo "[+] Generating config for Server B (Exit Node)..."
cat > "$OUTPUT_DIR/server_b/wg0.conf" << EOF
# Configuration for Server B (Exit Node)
[Interface]
Address = ${SERVER_B_TUNNEL_2_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_B_PRIV_KEY}
# Enable IP Forwarding and NAT
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -t nat -A POSTROUTING -s ${WG_TUNNEL_2_SUBNET} -o ${SERVER_B_MAIN_IFACE} -j MASQUERADE
PreDown = iptables -t nat -D POSTROUTING -s ${WG_TUNNEL_2_SUBNET} -o ${SERVER_B_MAIN_IFACE} -j MASQUERADE
PreDown = sysctl -w net.ipv4.ip_forward=0

# Peer: Server A
[Peer]
PublicKey = ${SERVER_A_PUB_KEY}
AllowedIPs = ${SERVER_A_TUNNEL_2_IP}/32
EOF

# == SERVER A (ENTRY NODE) CONFIGS ==
echo "[+] Generating configs for Server A (Entry Node)..."
# wg0 (Client-facing)
cat > "$OUTPUT_DIR/server_a/wg0.conf" << EOF
# Configuration for Server A - wg0 (Client-Facing)
[Interface]
Address = ${SERVER_A_TUNNEL_1_IP}/24
ListenPort = ${WG_PORT}
PrivateKey = ${SERVER_A_PRIV_KEY}
# Enable forwarding and setup policy routing rule for client traffic
PostUp = sysctl -w net.ipv4.ip_forward=1
PostUp = iptables -A FORWARD -i %i -o wg1 -j ACCEPT
PostUp = iptables -A FORWARD -i wg1 -o %i -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
PostUp = ip rule add from ${WG_TUNNEL_1_SUBNET%/*}/24 table 200
PreDown = ip rule del from ${WG_TUNNEL_1_SUBNET%/*}/24 table 200
PreDown = iptables -D FORWARD -i wg1 -o %i -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
PreDown = iptables -D FORWARD -i %i -o wg1 -j ACCEPT

# Peer: End-User Client
[Peer]
PublicKey = ${CLIENT_PUB_KEY}
AllowedIPs = ${CLIENT_TUNNEL_1_IP}/32
EOF

# wg1 (Exit-Node-facing)
cat > "$OUTPUT_DIR/server_a/wg1.conf" << EOF
# Configuration for Server A - wg1 (Exit-Node-Facing)
[Interface]
Table = off
Address = ${SERVER_A_TUNNEL_2_IP}/24
PrivateKey = ${SERVER_A_PRIV_KEY}
# Add default route to the custom routing table
PostUp = ip route add default via ${SERVER_B_TUNNEL_2_IP} table 200
PreDown = ip route del default via ${SERVER_B_TUNNEL_2_IP} table 200

# Peer: Server B (Exit Node)
[Peer]
PublicKey = ${SERVER_B_PUB_KEY}
Endpoint = ${SERVER_B_PUBLIC_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# == CLIENT CONFIG ==
echo "[+] Generating config for the Client..."
cat > "$OUTPUT_DIR/client/client.conf" << EOF
# Configuration for End-User Client
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_TUNNEL_1_IP}/24
DNS = 1.1.1.1, 1.0.0.1

# Peer: Server A (Entry Node)
[Peer]
PublicKey = ${SERVER_A_PUB_KEY}
Endpoint = ${SERVER_A_PUBLIC_IP}:${WG_PORT}
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# --- 4. GENERATE SUMMARY ---
echo "[+] Generating summary file..."
cat > "$OUTPUT_DIR/summary.txt" << EOF
# --- WireGuard Double-Hop VPN Summary ---

# Public Keys
Client Public Key:   ${CLIENT_PUB_KEY}
Server A Public Key: ${SERVER_A_PUB_KEY}
Server B Public Key: ${SERVER_B_PUB_KEY}

# Network Details
Server A Public IP:  ${SERVER_A_PUBLIC_IP}
Server B Public IP:  ${SERVER_B_PUBLIC_IP}
WireGuard Port:      ${WG_PORT}

# Tunnel 1 (Client <-> Server A)
Subnet:              ${WG_TUNNEL_1_SUBNET}
Server A IP:         ${SERVER_A_TUNNEL_1_IP}
Client IP:           ${CLIENT_TUNNEL_1_IP}

# Tunnel 2 (Server A <-> Server B)
Subnet:              ${WG_TUNNEL_2_SUBNET}
Server A IP:         ${SERVER_A_TUNNEL_2_IP}
Server B IP:         ${SERVER_B_TUNNEL_2_IP}
EOF

echo ""
echo "--- SUCCESS ---"
echo "Configuration files have been generated in the '$OUTPUT_DIR' directory."
echo "Review the files, then securely copy them to their respective machines."
