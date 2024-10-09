#!/bin/bash

# Story Validator Node Installer
# Spec: 4 Core, 8GB RAM, 200GB SSD

# Exit on error
set -e

# Define log file
LOG_FILE="$HOME/story_node_install.log"
touch $LOG_FILE

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output with timestamp
print_color() {
    local color=${2:-$GREEN}
    echo -e "${color}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}" | tee -a $LOG_FILE
}

# Function to print ASCII banner
print_banner() {
    echo -e "${BLUE}
  ____  _                _     _         _   _
 / ___|| |_ _   _  __ _ | |__ | |_ _   _| |_(_) ___  _ __
 \___ \| __| | | |/ _\` || '_ \| __| | | | __| |/ _ \| '_ \
  ___) | |_| |_| | (_| || | | | |_| |_| | |_| | (_) | | | |
 |____/ \__|\__,_|\__,_||_| |_|\__|\__,_|\__|_|\___/|_| |_|

    Story Validator Node Setup Script
    ${NC}"
}

# Function to show progress indicator
show_spinner() {
    local pid=$!
    local delay=0.1
    local spinner=( '|' '/' '-' '\' )
    while [ -d /proc/$pid ]; do
        for i in "${spinner[@]}"; do
            echo -ne "\r[$i] Working... "
            sleep $delay
        done
    done
    echo -ne "\r[✓] Done!              \n"
}

# 1. Update and install necessary packages
install_packages() {
    print_color "Step 1: Updating system and installing necessary packages..." $BLUE
    sudo apt update &> /dev/null && sudo apt -y upgrade &> /dev/null
    sudo apt install -y curl git make jq build-essential gcc unzip wget lz4 aria2 &> /dev/null &
    show_spinner
}

# 2. Download and install node files
download_binaries() {
    print_color "Step 2: Downloading and installing Story node files..." $BLUE
    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz &
    show_spinner
    tar -xzvf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz &> /dev/null
    [ ! -d "$HOME/go/bin" ] && mkdir -p $HOME/go/bin
    echo 'export PATH=$PATH:$HOME/go/bin' >> "$HOME/.bash_profile"
    sudo cp geth-linux-amd64-0.9.2-ea9f0d2/geth $HOME/go/bin/story-geth

    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz &
    show_spinner
    tar -xzvf story-linux-amd64-0.9.11-2a25df1.tar.gz &> /dev/null
    sudo cp story-linux-amd64-0.9.11-2a25df1/story $HOME/go/bin/story
}

# 3. Initialize Story node
initialize_node() {
    print_color "Step 3: Initializing Story node..." $BLUE
    read -p "Enter your moniker (node name): " MONIKER
    story init --network iliad --moniker "$MONIKER"
    story init --network iliad
}

# 4. Create system services
create_services() {
    print_color "Step 4: Creating Story systemd services..." $BLUE
    sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target
[Service]
User=root
ExecStart=/root/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target
[Service]
User=root
ExecStart=/root/go/bin/story run
Restart=on-failure
RestartSec=3
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOF
}

# 5. Start services and update peers
start_services() {
    print_color "Step 5: Starting services and updating peers..." $BLUE
    sudo systemctl daemon-reload
    sudo systemctl start story-geth
    sudo systemctl enable story-geth
    sudo systemctl start story
    sudo systemctl enable story

    sed -i.bak -e "s/^persistent_peers *=.*/persistent_peers = \"$(curl -sS https://story-testnet-rpc.polkachu.com/net_info | jq -r '.result.peers[] | "\(.node_info.id)@\(.remote_ip):\(.node_info.listen_addr)"' | awk -F ':' '{print $1":"$(NF)}' | paste -sd, -)\"/" $HOME/.story/story/config/config.toml

    sudo systemctl restart story
    sudo systemctl restart story-geth
}

# 6. Wait for node sync
wait_for_sync() {
    print_color "Step 6: Waiting for node sync (this could take some time)..." $YELLOW
    while true; do
        sync_status=$(curl -s localhost:26657/status | jq -r '.result.sync_info.catching_up')
        if [ "$sync_status" = "false" ]; then
            print_color "Node is fully synced!" $GREEN
            break
        else
            print_color "Node is still syncing. Current block height: $(curl -s localhost:26657/status | jq -r '.result.sync_info.latest_block_height')" $YELLOW
            sleep 60
        fi
    done
}

# 7. Export validator keys
export_validator_keys() {
    print_color "Step 7: Exporting validator keys..." $BLUE
    story validator export --export-evm-key
    cat /root/.story/story/config/private_key.txt | tee -a $LOG_FILE
}

# 8. Create validator
create_validator() {
    print_color "Step 8: Creating validator..." $BLUE
    story validator create --stake 500000000000000000
}

# 9. Final instructions
final_instructions() {
    print_color "Installation complete! Your Story validator node is now set up and running." $GREEN
    echo "Please check the log at $LOG_FILE for more details."
}

# Display ASCII banner
print_banner

# Run all steps
install_packages
download_binaries
initialize_node
create_services
start_services
wait_for_sync
export_validator_keys
create_validator
final_instructions
