#!/bin/bash

# TITLE: Network Recon and Aggressive Scanning
# AUTHOR: Szymon Stefański ( KN PING GDAŃSK )
# DESCRIPTION: This script performs a network scan to discover alive hosts
# and runs aggressive scans on the first discovered host. It also captures
# some passive network intelligence
# VERSION: 2.0

LOOT_DIR_SCAN="/root/loot/scan_results"
LOOT_DIR_AUDIT="/root/loot/audit_results"
SCAN_TIME=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p $LOOT_DIR_SCAN
mkdir -p $LOOT_DIR_AUDIT

# >>>>> SETUP <<<<<

# Setting up client mode for stealth and Internet access

LED SETUP
SERIAL_WRITE "[*] Configuring network..." # SERIAL_WRITE is used to send messages to the serial console
NETMODE DHCP_CLIENT
sleep 10

# Gathering network information and Shark Jack's IP address

IP=""
TIMEOUT=0
while [ -z "$IP" ]; do
    IP=$(ifconfig eth0 | grep 'inet' | awk -F: '{print $2}' | awk '{print $1}')
    # we check interface eth0 for the assigned IP address
    # then using grep we select IPv4 line
    # awk is used to extract the IP address from the output
    sleep 2
    TIMEOUT=$((TIMEOUT + 2))
    if [ $TIMEOUT -ge 30 ]; then
        SERIAL_WRITE "[!] Failed to obtain IP address."
        LED FAIL
        exit 1
    fi
done

GATEWAY=$(route -n | grep 'UG' | awk '{print $2}')
SUBNET=$(echo $IP | awk -F. '{print $1"."$2"."$3".0/24"}')
# We set the subnet based on the Shark Jack's IP, asuming a /24 network

# Save network info to network_info.txt

echo "============================================" > $LOOT_DIR_SCAN/network_info.txt
echo "Shark Jack Network Report" >> $LOOT_DIR_SCAN/network_info.txt
echo "Scan Time: $SCAN_TIME" >> $LOOT_DIR_SCAN/network_info.txt
echo "============================================" >> $LOOT_DIR_SCAN/network_info.txt
echo "SJC IP: $IP" >> $LOOT_DIR_SCAN/network_info.txt
echo "Gateway: $GATEWAY" >> $LOOT_DIR_SCAN/network_info.txt
echo "Subnet: $SUBNET" >> $LOOT_DIR_SCAN/network_info.txt
echo "============================================" >> $LOOT_DIR_SCAN/network_info.txt

SERIAL_WRITE "[*] IP: $IP"
SERIAL_WRITE "[*] Gateway: $GATEWAY"
SERIAL_WRITE "[*] Subnet: $SUBNET"

# >>>>> HOST DISCOVERY AND DEEP SCANNING <<<<<

# Host discovery and deep scanning

LED ATTACK
SERIAL_WRITE "[*] Discovering alive hosts..."
nmap -sn $SUBNET -oG $LOOT_DIR_SCAN/alive_hosts.txt

# Count alive hosts ( we exclude the gateway and the Shark Jack itself using grep -v )

HOST_COUNT=$(grep "Up" $LOOT_DIR_SCAN/alive_hosts.txt | grep -v "$GATEWAY" | grep -v "$IP" | wc -l)
ALIVE_HOSTS=$(grep "Up" $LOOT_DIR_SCAN/alive_hosts.txt | grep -v "$GATEWAY" | grep -v "$IP" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')

if [ -z "$ALIVE_HOSTS" ]; then
    SERIAL_WRITE "[!] No targets found on the network."
    LED FAIL
    exit 1
fi

SERIAL_WRITE "[*] Deep port scanning all alive hosts..."
nmap -sV -O -T4 --top-ports 100 $SUBNET -oN $LOOT_DIR_SCAN/deep_scan.txt
sleep 5
nmap -sV -A $GATEWAY -oN $LOOT_DIR_SCAN/gateway_scan.txt

# >>>>> AGGRESSIVE SCANNING <<<<<

# We take the first alive host, better for testing reason
# For production / real use it is recommended to implement logic to select the most interesting target
# based on open ports and services or any other criteria.
# For example based on deep_scan.txt and gateway_scan we could select hosts with specfic services
# and / or ports open.

TARGET_IP=$(echo "$ALIVE_HOSTS" | head -n 1)
SERIAL_WRITE "[*] Aggressive scan on $TARGET_IP..."

# Aggressive scan with OS detection, version detection, script scanning and traceroute
# Limiting to top 20 ports, for speed and storage reasons on Shark Jack

nmap -sV -O -A --osscan-guess --top-ports 20 $TARGET_IP -oN $LOOT_DIR_AUDIT/detailed_audit_$TARGET_IP.txt

# >>>>> TRAFFIC CAPTURE <<<<<

# Passive traffic capture for network intelligence

SERIAL_WRITE "[*] Capturing broadcast traffic (60s)..."

# Capture MDNS (device names and services)

tcpdump -i eth0 -vv -t udp port 5353 -c 100 > $LOOT_DIR_SCAN/mdns_devices.txt 2>&1 &

# Capture ARP traffic (who is talking to whom)

tcpdump -i eth0 -n arp -c 100 > $LOOT_DIR_SCAN/arp_traffic.txt 2>&1 &

# Capture any unencrypted HTTP traffic

tcpdump -i eth0 -A -l -c 100 'tcp port 80' > $LOOT_DIR_SCAN/http_traffic.txt 2>&1 &

sleep 60

# >>>>> CLEANUP AND FINAL REPORT <<<<<

# Clean up and final report
SERIAL_WRITE "[*] Generating final report..."
LED CLEANUP

killall tcpdump 2>/dev/null
killall nmap 2>/dev/null

# Generate summary report
echo "============================================" > $LOOT_DIR_SCAN/SUMMARY.txt
echo "SCAN SUMMARY" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "============================================" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "Date: $SCAN_TIME" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "SJC IP: $IP" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "Gateway: $GATEWAY" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "Subnet: $SUBNET" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "Hosts Found: $HOST_COUNT" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "Primary Target: $TARGET_IP" >> $LOOT_DIR_SCAN/SUMMARY.txt
echo "============================================" >> $LOOT_DIR_SCAN/SUMMARY.txt

SERIAL_WRITE "[*] Scan complete. Results saved to $LOOT_DIR_SCAN and $LOOT_DIR_AUDIT"
SERIAL_WRITE "[*] Files generated:"
SERIAL_WRITE "    - network_info.txt"
SERIAL_WRITE "    - alive_hosts.txt"
SERIAL_WRITE "    - deep_scan.txt"
SERIAL_WRITE "    - gateway_scan.txt"
SERIAL_WRITE "    - detailed_audit_*.txt"
SERIAL_WRITE "    - mdns_devices.txt"
SERIAL_WRITE "    - arp_traffic.txt"
SERIAL_WRITE "    - http_traffic.txt"
SERIAL_WRITE "    - SUMMARY.txt"

LED FINISH