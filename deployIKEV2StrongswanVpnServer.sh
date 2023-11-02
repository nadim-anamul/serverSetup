#!/bin/bash

# Step 1: Install StrongSwan and required plugins
sudo apt update
sudo apt install strongswan strongswan-pki libcharon-extra-plugins libcharon-extauth-plugins libstrongswan-extra-plugins -y

# Step 2: Install Certbot and obtain domain and email from user
sudo apt install certbot -y
read -p "Enter your domain: " domain
read -p "Enter your email: " email

sudo ufw allow 80/tcp
sudo ufw enable

sudo certbot certonly --rsa-key-size 4096 --key-type rsa --standalone --agree-tos --no-eff-email --email $email -d $domain
# Step 3: Move domain certificates to ipsec.d folder
sudo cp /etc/letsencrypt/live/$domain/fullchain.pem /etc/ipsec.d/certs/
sudo cp /etc/letsencrypt/live/$domain/privkey.pem /etc/ipsec.d/private/
sudo cp /etc/letsencrypt/live/$domain/chain.pem /etc/ipsec.d/cacerts/

# Step 4: Configure ipsec.conf
sudo cp /etc/ipsec.conf /etc/ipsec.conf.backup
cat <<EOF | sudo tee /etc/ipsec.conf >/dev/null
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=never

conn bcl-vpn
    auto=add
    compress=no
    type=tunnel
    keyexchange=ikev2
    ike=aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes256-aes128-sha256-sha1-modp2048-modp4096-modp1024,aes256-sha1-modp1024,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16-aes256gcm12-aes128gcm16-aes128gcm12-sha256-sha1-modp2048-modp4096-modp1024,3des-sha1-modp1024,aes256gcm16-prfsha384-ecp384!
    esp=aes128-aes256-sha1-sha256-modp2048-modp4096-modp1024,aes128-sha1,aes128-sha1-modp1024,aes128-sha1-modp1536,aes128-sha1-modp2048,aes128-sha256,aes128-sha256-ecp256,aes128-sha256-modp1024,aes128-sha256-modp1536,aes128-sha256-modp2048,aes128gcm12-aes128gcm16-aes256gcm12-aes256gcm16-modp2048-modp4096-modp1024,aes128gcm16,aes128gcm16-ecp256,aes256-sha1,aes256-sha256,aes256-sha256-modp1024,aes256-sha256-modp1536,aes256-sha256-modp2048,aes256-sha256-modp4096,aes256-sha384,aes256-sha384-ecp384,aes256-sha384-modp1024,aes256-sha384-modp1536,aes256-sha384-modp2048,aes256-sha384-modp4096,aes256gcm16,aes256gcm16-ecp384,3des-sha1!
    fragmentation=yes
    forceencaps=yes
    dpdaction=clear
    dpddelay=300s
    rekey=no
    left=%any
    leftid=@$domain
    leftcert=fullchain.pem
    leftsendcert=always
    leftsubnet=0.0.0.0/0
    right=%any
    rightid=%any
    rightauth=eap-mschapv2
    rightsourceip=10.10.10.0/24
    rightdns=8.8.8.8,8.8.4.4
    rightsendcert=never
    eap_identity=%identity
EOF

# Step 5: Configure VPN Authentication for username and password
read -p "Enter VPN username: " username
read -s -p "Enter VPN password: " password
echo -e "$domain : RSA \"privkey.pem\"" | sudo tee -a /etc/ipsec.secrets
echo -e "$username : EAP \"$password\"" | sudo tee -a /etc/ipsec.secrets

# Restart StrongSwan
sudo systemctl restart strongswan-starter

# Step 6: Configure UFW and enable NAT
sudo ufw allow OpenSSH
sudo ufw enable
sudo ufw allow 500,4500/udp

# Create a temporary file to store the new rules
# Define the new rules
new_rules="-A ufw-before-forward --match policy --pol ipsec --dir in --proto esp -s 10.10.10.0/24 -j ACCEPT"
new_rules="$new_rules\n-A ufw-before-forward --match policy --pol ipsec --dir out --proto esp -d 10.10.10.0/24 -j ACCEPT"

# Temporary file to store modified content
temp_file2=$(mktemp)

# Insert new rules into before.rules file before the last line (COMMIT)
sudo awk '/COMMIT/ {print "'"$new_rules"'"; print} !/COMMIT/' /etc/ufw/before.rules >"$temp_file2"
sudo cat "$temp_file2" >/etc/ufw/before.rules
# Overwrite the original file with the modified content
sudo mv "$temp_file2" /etc/ufw/before.rules
# Create a temporary file to store the new rules
tmpfile=$(mktemp)

# Add the new rules to the temporary file
echo "*nat" >>"$tmpfile"
echo "-A POSTROUTING -s 10.10.10.0/24 -o eth0 -m policy --pol ipsec --dir out -j ACCEPT" >>"$tmpfile"
echo "-A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE" >>"$tmpfile"
echo "COMMIT" >>"$tmpfile"
echo "*mangle" >>"$tmpfile"
echo "-A FORWARD --match policy --pol ipsec --dir in -s 10.10.10.0/24 -o eth0 -p tcp -m tcp --tcp-flags SYN,RST SYN -m tcpmss --mss 1361:1536 -j TCPMSS --set-mss 1360" >>"$tmpfile"
echo "COMMIT" >>"$tmpfile"

# Concatenate the original file content to the temporary file
sudo cat /etc/ufw/before.rules >>"$tmpfile"

# Overwrite the original file with the modified content
sudo mv "$tmpfile" /etc/ufw/before.rules

# UFW’s kernel parameters configuration
echo "net/ipv4/ip_forward=1" | sudo tee -a /etc/ufw/sysctl.conf
echo "net/ipv4/conf/all/accept_redirects=0" | sudo tee -a /etc/ufw/sysctl.conf
echo "net/ipv4/conf/all/send_redirects=0" | sudo tee -a /etc/ufw/sysctl.conf
echo "net/ipv4/ip_no_pmtu_disc=1" | sudo tee -a /etc/ufw/sysctl.conf

# Restart UFW to apply the changes
sudo ufw disable
sudo ufw enable

# Show success message
echo "IKEv2 VPN server setup completed. Your VPN server is ready to use."
