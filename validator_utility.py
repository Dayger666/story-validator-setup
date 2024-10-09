#!/usr/bin/env python3

import requests
import json
import argparse
from tabulate import tabulate
from colorama import Fore, Style, init

# Initialize colorama for cross-platform colored output
init(autoreset=True)

class StoryValidatorUtility:
    def __init__(self, rpc_url):
        self.rpc_url = rpc_url

    def make_request(self, method, params=None):
        headers = {'Content-Type': 'application/json'}
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or []
        }
        try:
            response = requests.post(self.rpc_url, headers=headers, data=json.dumps(payload))
            response.raise_for_status()  # Check for HTTP errors
            return response.json()['result']
        except requests.exceptions.RequestException as e:
            print(f"{Fore.RED}Error: {e}{Style.RESET_ALL}")
            return None

    def print_node_info(self):
        info = self.make_request("status")
        if info:
            print(f"{Fore.GREEN}Node Information:{Style.RESET_ALL}")
            print(f"Node ID: {info['node_info']['id']}")
            print(f"Moniker: {info['node_info']['moniker']}")
            print(f"Network: {info['node_info']['network']}")
            print(f"Latest Block Height: {info['sync_info']['latest_block_height']}")
            print(f"Catching Up: {info['sync_info']['catching_up']}")

    # More methods like print_validators, print_peers, etc.

def main():
    parser = argparse.ArgumentParser(description="Enhanced Story Blockchain Validator Utility")
    parser.add_argument("--rpc", default="http://localhost:26657", help="RPC endpoint URL")
    parser.add_argument("--action", choices=["health", "node", "validators", "peers", "block", "sync"],
                        default="health", help="Action to perform")
    args = parser.parse_args()

    utility = StoryValidatorUtility(args.rpc)

    actions = {
        "health": utility.print_node_info,  # Add more actions as required
    }

    actions[args.action]()

if __name__ == "__main__":
    main()
