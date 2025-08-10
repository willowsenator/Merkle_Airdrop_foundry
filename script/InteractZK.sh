#!/bin/bash

CLAIMING_ZKSYNC_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
CLAIMING_ZKSYNC_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
PAYER_ZKSYNC_KEY=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
CLAIMING_AMOUNT=25000000000000000000 # 25 tokens in wei
RPC_URL=http://127.0.0.1:8011

ROOT=0x7e2cbef7bfe87caa8da6075469a352eb93e305f541cae0a0db98899bb9013a06
PROOF_ONE=0x8ebcc963f0588d1ded1ebd0d349946755f27e95d1917f9427a207d8935e04d4b
PROOF_TWO=0x67ac38a0ee927516de8ed257ce3ecc9b1c02daf12cde2da8ffaf12582431f3d7

echo "Deploying token..."
TOKEN_ADDRESS=$(forge create BagelToken --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync --broadcast | awk '/Deployed to:/ {print $3}')
echo "Token deployed at: $TOKEN_ADDRESS"

echo "Deploying airdrop..."
AIRDROP_ADDRESS=$(forge create MerkleAirdrop --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync --broadcast --constructor-args $ROOT $TOKEN_ADDRESS | awk '/Deployed to:/ {print $3}')
echo "Airdrop deployed at: $AIRDROP_ADDRESS"

echo "Minting tokens..."
cast send $TOKEN_ADDRESS "mint(address,uint256)" $CLAIMING_ZKSYNC_ADDRESS $CLAIMING_AMOUNT --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync
echo "Transferring tokens to airdrop contract..."
cast send $TOKEN_ADDRESS "transfer(address,uint256)" $AIRDROP_ADDRESS $CLAIMING_AMOUNT --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync
echo "Tokens transferred to airdrop contract."

MESSAGE_HASH=$(cast call $AIRDROP_ADDRESS "getMessageHash(address,uint256)" $CLAIMING_ZKSYNC_ADDRESS $CLAIMING_AMOUNT --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync)
echo "Message hash: $MESSAGE_HASH"
echo "Signing message..."
SIGNATURE=$(cast wallet sign $MESSAGE_HASH --private-key $CLAIMING_ZKSYNC_KEY --no-hash)
echo "Signature: $SIGNATURE"
SIGNATURE_SPLIT=$(forge script SplitSignature --sig "splitSignature(bytes)" $SIGNATURE --rpc-url $RPC_URL --private-key $CLAIMING_ZKSYNC_KEY --zksync)
echo "Signature split: $SIGNATURE_SPLIT"

v=$(echo $SIGNATURE_SPLIT | grep -oP 'v: uint8 \K\d+')
r=$(echo $SIGNATURE_SPLIT | grep -oP 'r: bytes32 \K0x[a-fA-F0-9]+')
s=$(echo $SIGNATURE_SPLIT | grep -oP 's: bytes32 \K0x[a-fA-F0-9]+')

echo "Signature components:"
echo "v: $v"
echo "r: $r"
echo "s: $s"

echo "Claiming tokens..."
cast send $AIRDROP_ADDRESS "claim(address,uint256,bytes32[],uint8,bytes32,bytes32)" $CLAIMING_ZKSYNC_ADDRESS $CLAIMING_AMOUNT "[$PROOF_ONE, $PROOF_TWO]" $v $r $s --rpc-url $RPC_URL --private-key $PAYER_ZKSYNC_KEY --zksync

echo "Balance of airdrop contract:"
BALANCE=$(cast call $TOKEN_ADDRESS "balanceOf(address)" $CLAIMING_ZKSYNC_ADDRESS --rpc-url $RPC_URL --zksync)
echo "Airdrop contract balance (in tokens): $(cast --to-dec $BALANCE)"

