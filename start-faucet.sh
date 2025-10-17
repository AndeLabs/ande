#!/bin/bash
export FAUCET_PORT=3001
export RPC_URL=http://localhost:8545
export FAUCET_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Modify the faucet amount in the server temporarily
node -e "
const fs = require('fs');
const content = fs.readFileSync('faucet-server.js', 'utf8');
const modified = content.replace(/parseEther\('1000000000'\)/, \"parseEther('10')\");
fs.writeFileSync('/tmp/faucet-server-modified.js', modified);
"

node /tmp/faucet-server-modified.js
