#!/bin/bash

# Your configuration
CLAIMING_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
CLAIMING_AMOUNT="25000000000000000000" # 25 tokens in wei
PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
RPC_URL="http://127.0.0.1:8545" # Anvil RPC URL

echo "Deploying the contracts..."

forge script DeployMerkleAirdrop --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast

CHAIN_ID=$(cast chain-id --rpc-url $RPC_URL)
echo "Chain ID: $CHAIN_ID"

BROADCAST_FILE="broadcast/DeployMerkleAirdrop.s.sol/$CHAIN_ID/run-latest.json"

if [ ! -f "$BROADCAST_FILE" ]; then
    echo "Broadcast file not found: $BROADCAST_FILE"
    echo "Available files:"
    ls -la broadcast/DeployMerkleAirdrop.s.sol/ 2>/dev/null || echo "No broadcast directory found."
    exit 1
fi

echo "Reading from broadcast file: $BROADCAST_FILE"

echo "Broadcast file structure:"
jq  '.' "$BROADCAST_FILE"

# Extract contract addresses from transactions
AIRDROP_CONTRACT=$(jq -r '.transactions[]? | select(.contractName == "MerkleAirdrop") | .contractAddress' "$BROADCAST_FILE")
TOKEN_CONTRACT=$(jq -r '.transactions[]? | select(.contractName == "BagelToken") | .contractAddress' "$BROADCAST_FILE")

# If not found in transactions, try receipts
if [ -z "$AIRDROP_CONTRACT" ] || [ "$AIRDROP_CONTRACT" == "null" ]; then
    echo "Trying to extract from receipts..."
    AIRDROP_CONTRACT=$(jq -r '.receipts[]? | select(.contractName == "MerkleAirdrop") | .contractAddress' "$BROADCAST_FILE")
    TOKEN_CONTRACT=$(jq -r '.receipts[]? | select(.contractName == "BagelToken") | .contractAddress' "$BROADCAST_FILE")
fi

# Alternative: Extract from logs if contract names aren't available
if [ -z "$AIRDROP_CONTRACT" ] || [ "$AIRDROP_CONTRACT" == "null" ]; then
    echo "Extracting from deployment order..."
    # Usually BagelToken is deployed first, then MerkleAirdrop
    TOKEN_CONTRACT=$(jq -r '.transactions[0].contractAddress' "$BROADCAST_FILE")
    AIRDROP_CONTRACT=$(jq -r '.transactions[1].contractAddress' "$BROADCAST_FILE")
fi

echo "Airdrop Contract Address: $AIRDROP_CONTRACT"
echo "Token Contract Address: $TOKEN_CONTRACT"

# Verify we got the valid addresses
if [ -z "$AIRDROP_CONTRACT" ] || [ "$AIRDROP_CONTRACT" == "null" ]; then
    echo "Failed to extract Airdrop contract address"
    echo "Let's see what's in the transactions:"
    jq '.transactions' "$BROADCAST_FILE"
    exit 1
fi

# Gnerate signature
echo "Generating signature..."
MESSAGE_HASH=$(cast call $AIRDROP_CONTRACT "getMessageHash(address,uint256)" $CLAIMING_ADDRESS $CLAIMING_AMOUNT --rpc-url $RPC_URL)
echo "Message Hash: $MESSAGE_HASH"

# Sigm the message hash
SIGNATURE=$(cast wallet sign $MESSAGE_HASH --private-key $PRIVATE_KEY --no-hash)
echo "Generated signature: $SIGNATURE"

# Remove 0x prefix from the signature
SIGNATURE_HEX=${SIGNATURE#0x}
echo ""
echo "=== RESULTS ==="
echo "Airdrop Contract: $AIRDROP_CONTRACT"
echo "Token Contract: $TOKEN_CONTRACT"
echo "Claiming Address: $CLAIMING_ADDRESS"
echo "Claiming Amount: $CLAIMING_AMOUNT"
echo "Message Hash: $MESSAGE_HASH"
echo "Full Signature: $SIGNATURE"
echo "Signature for Solidity: hex\"$SIGNATURE_HEX\""

