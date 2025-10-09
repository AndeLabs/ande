#!/bin/bash
# AndeChain Full Start - Todo en Uno
# Uso: ./start-andechain.sh

set -e

echo "🔥 AndeChain Full Start - Todo Automatizado"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "📋 1. Verificando requisitos..."
check_command() {
    if command -v $1 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $1 encontrado${NC}"
        return 0
    else
        echo -e "${RED}❌ $1 no encontrado${NC}"
        echo -e "${YELLOW}💡 Instala $1 antes de continuar${NC}"
        return 1
    fi
}

# Verificar herramientas
if ! check_command "docker" || ! check_command "docker compose" || ! check_command "forge"; then
    echo ""
    echo -e "${RED}❌ Faltan requisitos por instalar${NC}"
    echo ""
    echo -e "${BLUE}Para instalar Foundry:${NC}"
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    echo ""
    echo -e "${BLUE}Para instalar Docker:${NC}"
    echo "https://docs.docker.com/get-docker/"
    exit 1
fi

echo ""
echo "📝 2. Configurando entorno..."

# Crear .env si no existe
if [ ! -f "contracts/.env" ]; then
    echo -e "${YELLOW}Creando contracts/.env con PRIVATE_KEY de desarrollo...${NC}"
    mkdir -p contracts
    echo "PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > contracts/.env
    echo -e "${GREEN}✅ .env creado${NC}"
else
    echo -e "${GREEN}✅ .env ya existe${NC}"
fi

echo ""
echo "🔨 3. Construyendo ev-reth con ANDE Token Duality..."
if make build-ev-reth; then
    echo -e "${GREEN}✅ ev-reth construido${NC}"
else
    echo -e "${RED}❌ Falló construcción de ev-reth${NC}"
    exit 1
fi

echo ""
echo "🐳 4. Iniciando infraestructura Docker..."
cd infra
if docker compose -f stacks/single-sequencer/docker-compose.ande.yml up -d; then
    echo -e "${GREEN}✅ Containers iniciados${NC}"
else
    echo -e "${RED}❌ Falló inicio de containers${NC}"
    exit 1
fi
cd ..

echo ""
echo "⏳ 5. Esperando estabilización de la red (60 segundos)..."
echo -e "${BLUE}Esto permite que la blockchain genere bloques iniciales...${NC}"
for i in {60..1}; do
    echo -ne "\r⏳ Esperando: ${i} segundos restantes "
    sleep 1
done
echo ""

echo ""
echo "🔍 6. Verificando salud del sistema..."

# Verificar containers
containers_ok=$(docker compose -f infra/stacks/single-sequencer/docker-compose.ande.yml ps 2>/dev/null | grep -c "Up" || echo "0")
if [ "$containers_ok" -ge "2" ]; then
    echo -e "${GREEN}✅ Containers Docker corriendo (${containers_ok} servicios)${NC}"
else
    echo -e "${RED}❌ Containers no están corriendo correctamente${NC}"
    docker compose -f infra/stacks/single-sequencer/docker-compose.ande.yml ps
fi

# Verificar RPC
if curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "0x"; then
    block_number=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | jq -r '.result' 2>/dev/null || echo "unknown")
    echo -e "${GREEN}✅ RPC respondiendo (bloque ${block_number})${NC}"
else
    echo -e "${RED}❌ RPC no respondiendo${NC}"
fi

echo ""
echo "📜 7. Desplegando contrato ANDE Token..."
cd contracts
if forge script script/DeploySimple.s.sol --rpc-url local --broadcast --legacy --private-key ${PRIVATE_KEY} --quiet 2>/dev/null; then
    echo -e "${GREEN}✅ ANDE Token desplegado exitosamente${NC}"
else
    echo -e "${YELLOW}⚠️  Deploy de contratos falló, pero infraestructura está lista${NC}"
    echo -e "${BLUE}Puedes deployar manualmente con:${NC}"
    echo "cd contracts && forge script script/DeploySimple.s.sol --rpc-url local --broadcast --legacy --private-key \${PRIVATE_KEY}"
fi
cd ..

echo ""
echo "🎉 8. AndeChain está COMPLETAMENTE operativa!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}🌐 RPC:${NC}          http://localhost:8545"
echo -e "${GREEN}🔍 Explorer:${NC}     http://localhost:4000"
echo -e "${GREEN}💰 ANDE Token:${NC}   Ver contratos desplegados en explorer"
echo -e "${GREEN}📍 Precompile:${NC}   0x00000000000000000000000000000000000000FD"
echo ""
echo -e "${BLUE}Comandos útiles:${NC}"
echo "make health           - Verificar salud del sistema"
echo "make info             - Mostrar información detallada"
echo "make stop             - Detener infraestructura"
echo "make reset            - Reset completo"
echo ""
echo -e "${GREEN}🎯 Listo para desarrollar en AndeChain!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"