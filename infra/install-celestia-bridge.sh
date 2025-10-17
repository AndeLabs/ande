#!/bin/bash
set -e

echo "=================================================="
echo "🌉 Celestia Bridge Node Setup for AndeChain"
echo "   Mocha-4 Testnet | v0.27.5-mocha"
echo "=================================================="
echo ""

# Detectar arquitectura
ARCH=$(uname -m)
OS=$(uname -s)

if [ "$OS" == "Darwin" ]; then
    if [ "$ARCH" == "arm64" ]; then
        BINARY_URL="https://github.com/celestiaorg/celestia-node/releases/download/v0.27.5-mocha/celestia-node_Darwin_arm64.tar.gz"
    else
        BINARY_URL="https://github.com/celestiaorg/celestia-node/releases/download/v0.27.5-mocha/celestia-node_Darwin_x86_64.tar.gz"
    fi
elif [ "$OS" == "Linux" ]; then
    if [ "$ARCH" == "aarch64" ]; then
        BINARY_URL="https://github.com/celestiaorg/celestia-node/releases/download/v0.27.5-mocha/celestia-node_Linux_arm64.tar.gz"
    else
        BINARY_URL="https://github.com/celestiaorg/celestia-node/releases/download/v0.27.5-mocha/celestia-node_Linux_x86_64.tar.gz"
    fi
else
    echo "❌ OS no soportado: $OS"
    exit 1
fi

echo "📦 Descargando Celestia Node v0.27.5-mocha..."
echo "   OS: $OS | Arch: $ARCH"
echo "   URL: $BINARY_URL"
echo ""

cd /tmp
wget -q --show-progress "$BINARY_URL" -O celestia-node.tar.gz

echo ""
echo "📂 Extrayendo binario..."
tar -xzf celestia-node.tar.gz

echo "📥 Instalando en /usr/local/bin..."
sudo mv celestia /usr/local/bin/
sudo chmod +x /usr/local/bin/celestia

# Limpiar
rm -f celestia-node.tar.gz

echo ""
echo "✅ Celestia instalado correctamente"
celestia version
echo ""

echo "🔧 Inicializando Bridge Node para Mocha-4..."
celestia bridge init --p2p.network mocha

echo ""
echo "🔑 Generando Auth Token..."
AUTH_TOKEN=$(celestia bridge auth admin --p2p.network mocha)
echo ""
echo "=================================================="
echo "✅ SETUP COMPLETO"
echo "=================================================="
echo ""
echo "📋 INFORMACIÓN IMPORTANTE:"
echo ""
echo "1️⃣  Auth Token (guarda esto de forma segura):"
echo "   $AUTH_TOKEN"
echo ""
echo "2️⃣  Wallet Address (fondear con TIA):"
WALLET_ADDR=$(celestia state account-address --node.store ~/.celestia-bridge-mocha-4)
echo "   $WALLET_ADDR"
echo ""
echo "3️⃣  Fondear wallet:"
echo "   - Faucet web: https://mocha.celenium.io/faucet"
echo "   - Discord: #mocha-faucet → \$request $WALLET_ADDR"
echo ""
echo "4️⃣  Actualizar evnode.yaml:"
echo "   da:"
echo "     address: http://localhost:26658"
echo "     auth_token: \"$AUTH_TOKEN\""
echo ""
echo "5️⃣  Iniciar Bridge Node:"
echo "   celestia bridge start \\"
echo "     --p2p.network mocha \\"
echo "     --core.ip public-celestia-mocha4-consensus.numia.xyz \\"
echo "     --core.port 9090 \\"
echo "     --rpc.addr 0.0.0.0 \\"
echo "     --rpc.port 26658 \\"
echo "     --metrics \\"
echo "     --metrics.endpoint 127.0.0.1:4318"
echo ""
echo "6️⃣  Verificar sync status:"
echo "   curl -s http://localhost:26658 -X POST \\"
echo "     -H \"Content-Type: application/json\" \\"
echo "     -H \"Authorization: Bearer \$AUTH_TOKEN\" \\"
echo "     -d '{\"jsonrpc\":\"2.0\",\"method\":\"header.SyncState\",\"params\":[],\"id\":1}' | jq"
echo ""
echo "=================================================="
echo "📚 Documentación:"
echo "   - Mocha Testnet: https://docs.celestia.org/how-to-guides/mocha-testnet"
echo "   - Node API: https://node-rpc-docs.celestia.org"
echo "=================================================="
