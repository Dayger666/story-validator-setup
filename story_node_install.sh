#!/bin/bash

# Enhanced Story Validator Installer Script
# Spec: 4 Core, 8GB RAM, 200GB SSD

# Exit on error and undefined variable
set -euo pipefail

# Function to print colored output
print_color() {
    case "$2" in
        "red") COLOR='\033[0;31m' ;;  # Red for errors
        "yellow") COLOR='\033[0;33m' ;;  # Yellow for warnings
        *) COLOR='\033[0;32m' ;;  # Green for success
    esac
    NC='\033[0m'
    printf "${COLOR}$1${NC}\n"
}

# Function to check if command exists
check_command() {
    command -v "$1" >/dev/null 2>&1 || {
        print_color "$1 is not installed. Installing..." "yellow"
        sudo apt install -y "$1"
    }
}

# Install essential packages if not already installed
install_packages() {
    print_color "Step 1: Installing necessary packages..."
    for pkg in curl git make jq gcc unzip wget lz4 aria2; do
        check_command "$pkg"
    done
    sudo apt update && sudo apt -y upgrade
}

# Download node binaries
download_binaries() {
    print_color "Step 2: Downloading Story node files..."
    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/geth-public/geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
    tar -xzf geth-linux-amd64-0.9.2-ea9f0d2.tar.gz
    [ ! -d "$HOME/go/bin" ] && mkdir -p "$HOME/go/bin"
    sudo cp geth-linux-amd64-0.9.2-ea9f0d2/geth "$HOME/go/bin/story-geth"

    wget -q https://story-geth-binaries.s3.us-west-1.amazonaws.com/story-public/story-linux-amd64-0.9.11-2a25df1.tar.gz
    tar -xzf story-linux-amd64-0.9.11-2a25df1.tar.gz
    sudo cp story-linux-amd64-0.9.11-2a25df1/story "$HOME/go/bin/story"
}

# Setup environment
setup_environment() {
    print_color "Step 3: Setting up environment variables..."
    if ! grep -q "$HOME/go/bin" "$HOME/.bash_profile"; then
        echo 'export PATH=$PATH:$HOME/go/bin' >> "$HOME/.bash_profile"
    fi
    source "$HOME/.bash_profile"
}

# Initialize the node
initialize_node() {
    print_color "Step 4: Initializing Story node..."
    read -rp "Enter your moniker (node name): " MONIKER
    story init --network iliad --moniker "$MONIKER"
}

# Create services
create_services() {
    print_color "Step 5: Creating service files..."
    sudo tee /etc/systemd/system/story-geth.service > /dev/null <<EOF
[Unit]
Description=Story Geth Client
After=network.target
[Service]
ExecStart=$HOME/go/bin/story-geth --iliad --syncmode full
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF

    sudo tee /etc/systemd/system/story.service > /dev/null <<EOF
[Unit]
Description=Story Consensus Client
After=network.target
[Service]
ExecStart=$HOME/go/bin/story run
Restart=on-failure
[Install]
WantedBy=multi-user.target
EOF
}

# Start services and check status
start_services() {
    print_color "Step 6: Starting services..."
    sudo systemctl daemon-reload
    sudo systemctl start story-geth
    sudo systemctl enable story-geth
    sudo systemctl start story
    sudo systemctl enable story

    print_color "Services started successfully!" "green"
}

# Run the setup
install_packages
download_binaries
setup_environment
initialize_node
create_services
start_services
print_color "Node setup complete!" "green"
