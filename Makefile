# ==========================================
# AndeChain Development Makefile
# ==========================================

.PHONY: help start stop reset test coverage security clean deploy-only deploy-ecosystem verify-contracts relayer faucet build-ev-reth health info fuzz gas snapshot

# Default target
help:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "    AndeChain - ANDE Token Duality System"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "🚀 Comandos Principales:"
	@echo "  make full-start         - 🔥 COMPLETO: Todo automatizado (requisitos + infra + deploy)"
	@echo "  make start              - Inicia infraestructura (sin verificar requisitos)"
	@echo "  make stop               - Detiene la infraestructura"
	@echo "  make reset              - Reset completo (borra volúmenes y artifacts)"
	@echo "  make health             - Verifica salud del sistema"
	@echo "  make info               - Muestra información del sistema"
	@echo ""
	@echo "📜 Smart Contracts:"
	@echo "  make test               - Ejecuta tests de contratos"
	@echo "  make coverage           - Genera reporte de cobertura"
	@echo "  make security           - Análisis de seguridad (Slither)"
	@echo "  make deploy-ecosystem   - Despliega ecosistema completo"
	@echo "  make redeploy-token     - Fuerza redeploy de ANDE Token con nueva dirección"
	@echo "  make verify-contracts   - Info sobre verificación en Blockscout"
	@echo ""
	@echo "🔧 Herramientas:"
	@echo "  make build-ev-reth      - Construye ev-reth ANDE desde GitHub"
	@echo "  make relayer            - Inicia relayer de bridge"
	@echo "  make faucet             - Inicia servidor de faucet"
	@echo "  make clean              - Limpia artifacts de compilación"
	@echo ""
	@echo "📦 Version Control:"
	@echo "  make version            - Muestra información de versiones"
	@echo "  make version-patch      - Incrementa versión patch"
	@echo "  make version-minor      - Incrementa versión minor"
	@echo "  make version-major      - Incrementa versión major"
	@echo ""
	@echo "💡 Sistema 100% ANDE Token Duality"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""

# Inicia el entorno completo con ANDE Token Duality
start: build-ev-reth
	@echo "🚀 Iniciando AndeChain con ANDE Token Duality..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml up -d --build
	@echo "⏳ Esperando 30 segundos para que la cadena se estabilice..."
	@sleep 30
	@echo "✅ AndeChain está lista!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🌐 RPC: http://localhost:8545"
	@echo "🔍 Explorer: http://localhost:4000"
	@echo "💰 ANDE Precompile: 0x00000000000000000000000000000000000000FD"
	@echo "ℹ️  Para desplegar contratos: make deploy-ecosystem"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 🔥 COMANDO COMPLETO AUTOMATIZADO - Todo en Uno
full-start:
	@echo "🔥 AndeChain Full Start - Todo Automatizado"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "📋 1. Verificando requisitos..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker no encontrado. Por favor instala Docker."; exit 1; }
	@command -v docker compose >/dev/null 2>&1 || { echo "❌ Docker Compose no encontrado. Por favor instala Docker Compose."; exit 1; }
	@command -v forge >/dev/null 2>&1 || { echo "❌ Foundry no encontrado. Ejecuta: curl -L https://foundry.paradigm.xyz | bash && foundryup"; exit 1; }
	@echo "✅ Requisitos verificados"
	@echo ""
	@echo "📝 2. Configurando entorno..."
	@if [ ! -f "contracts/.env" ]; then \
		echo "Creando contracts/.env con PRIVATE_KEY de desarrollo..."; \
		echo "PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > contracts/.env; \
		echo "✅ .env creado"; \
	else \
		echo "✅ .env ya existe"; \
	fi
	@echo ""
	@echo "🔨 3. Construyendo ev-reth con ANDE Token Duality..."
	@$(MAKE) build-ev-reth
	@echo ""
	@echo "🐳 4. Iniciando infraestructura Docker..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml up -d
	@echo ""
	@echo "⏳ 5. Esperando estabilización de la red (60 segundos)..."
	@sleep 60
	@echo ""
	@echo "🔍 6. Verificando salud del sistema..."
	@$(MAKE) health-quiet
	@echo ""
	@echo "📜 7. Desplegando contrato ANDE Token..."
	@echo "🔍 Verificando si ANDE Token ya está desplegado..."
	@if cast code 0x5FbDB2315678afecb367f032d93F642f64180aa3 --rpc-url local >/dev/null 2>&1; then \
		echo "✅ ANDE Token ya está desplegado en 0x5FbDB2315678afecb367f032d93F642f64180aa3"; \
		echo "📊 Verificando estado del contrato..."; \
		echo "   - Nombre: $$(cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "name()" --rpc-url local 2>/dev/null || echo "Verificando...")"; \
		echo "   - Símbolo: $$(cast call 0x5FbDB2315678afecb367f032d93F642f64180aa3 "symbol()" --rpc-url local 2>/dev/null || echo "Verificando...")"; \
	else \
		echo "📜 ANDE Token no encontrado. Desplegando..."; \
		cd contracts && \
		. ./.env && \
		forge script script/DeploySimple.s.sol --rpc-url local --broadcast --legacy --private-key $$PRIVATE_KEY --nonce $$(cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url local) && \
		echo "✅ ANDE Token desplegado exitosamente" || \
		echo "⚠️  Deploy falló, pero infraestructura lista"; \
	fi
	@echo ""
	@echo "🎉 8. AndeChain está COMPLETAMENTE operativa!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🌐 RPC:          http://localhost:8545"
	@echo "🔍 Explorer:     http://localhost:4000"
	@echo "💰 ANDE Token:   Ver contratos desplegados en explorer"
	@echo "📍 Precompile:   0x00000000000000000000000000000000000000FD"
	@echo "📊 Health Check: make health"
	@echo "🛑 Detener:      make stop"
	@echo "🔄 Reset:        make reset"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Health check sin output decorativo (para usar en scripts)
health-quiet:
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml ps | grep -q "Up" && echo "✅ Containers running" || echo "❌ Containers not running"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "0x" && echo "✅ RPC responding" || echo "❌ RPC not responding"

# Detiene la infraestructura
stop:
	@echo "Deteniendo infraestructura ANDE..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml down

# Reset completo (borra todo)
reset:
	@echo "🔄 Reset completo de AndeChain..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml down -v
	@rm -rf contracts/out contracts/cache contracts/broadcast
	@echo "✅ Sistema reseteado. Ejecuta 'make start' para comenzar de nuevo."

# Tests de contratos
test:
	@echo "Ejecutando tests de smart contracts..."
	@cd contracts && forge test -vv

# Cobertura de tests
coverage:
	@echo "Generando reporte de cobertura..."
	@cd contracts && forge coverage

# Análisis de seguridad
security:
	@echo "Ejecutando análisis de seguridad con Slither..."
	@docker compose -f infra/docker-compose.yml run --rm contracts slither /app

# Solo deploy (asume que la infraestructura está corriendo)
deploy-only:
	@echo "Desplegando contratos..."
	@cd contracts && \
		export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 && \
		forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast --legacy

# Relayer de bridge (asume que los contratos están desplegados)
relayer:
	@echo "Iniciando relayer..."
	@cd relayer && npm start

# Solo faucet (asume que la blockchain está corriendo)
faucet:
	@echo "🚰 Iniciando servidor de faucet..."
	@if [ ! -d "node_modules" ]; then \
		echo "📦 Instalando dependencias..."; \
		npm install; \
	fi
	@npm start

# Limpia artifacts
clean:
	@echo "Limpiando artifacts de compilación..."
	@cd contracts && forge clean
	@rm -rf contracts/out contracts/cache

# Fuzzing tests (cuando se implementen)
fuzz:
	@echo "Ejecutando fuzzing tests..."
	@cd contracts && forge test --fuzz-runs 10000

# Gas report
gas:
	@echo "Generando reporte de gas..."
	@cd contracts && forge test --gas-report

# Snapshot de gas (para comparar optimizaciones)
snapshot:
	@echo "Creando snapshot de gas..."
	@cd contracts && forge snapshot

# Despliega el ecosistema completo
deploy-ecosystem:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📜 Despliegue de Contratos Disponibles"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Scripts de despliegue disponibles:"
	@echo "  • DeploySimple.s.sol - Token ANDE básico"
	@echo "  • DeployAbob.s.sol - Sistema ABOB completo"
	@echo "  • DeployAndeBridge.s.sol - Bridge Ande"
	@echo "  • DeployAndTestVeANDE.s.sol - Sistema de gobernanza veANDE"
	@echo "  • DeployAndTestP2POracle.s.sol - Oráculo P2P"
	@echo ""
	@echo "Para desplegar, usa:"
	@echo "  cd contracts && forge script script/[SCRIPT_NAME] --rpc-url local --broadcast --legacy"
	@echo ""
	@echo "Ejemplo con token ANDE básico:"
	@cd contracts && \
		forge script script/DeploySimple.s.sol --rpc-url local --broadcast --legacy --private-key $${PRIVATE_KEY} || \
		echo "⚠️  Asegúrate de tener PRIVATE_KEY configurada en contracts/.env"

# Verifica contratos en Blockscout
verify-contracts:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "ℹ️  Blockscout verifica automáticamente los contratos"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "Los contratos se verifican en segundo plano cuando:"
	@echo "  1. Son desplegados en la red"
	@echo "  2. Blockscout indexa el bloque correspondiente"
	@echo ""
	@echo "Puedes ver el estado en: http://localhost:4000"
	@echo ""
	@echo "Para verificación manual, usa:"
	@echo "  forge verify-contract <ADDRESS> <CONTRACT> --verifier blockscout \\"
	@echo "    --verifier-url http://localhost:4000/api --chain-id 1234"
	@echo ""

# ==========================================
# System Health & Info
# ==========================================

# Verificar salud del sistema ANDE
health:
	@echo "🏥 Verificando salud de AndeChain..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📊 Estado de servicios:"
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml ps
	@echo ""
	@echo "🔗 Conectividad RPC:"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs -I {} echo "Chain ID: {}"
	@echo ""
	@echo "📦 Último bloque:"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs -I {} echo "Block: {}"
	@echo ""
	@echo "💰 Saldo ANDE de precompile:"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_getBalance","params":["0x00000000000000000000000000000000000000FD","latest"],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs -I {} echo "ANDE Balance: {} wei"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Mostrar información del sistema ANDE
info:
	@echo "📋 Información de AndeChain - ANDE Token Duality"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🔗 Versión de ev-reth:"
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.ande.yml exec ev-reth-sequencer ev-reth --version 2>/dev/null || echo "ev-reth no disponible"
	@echo ""
	@echo "📍 Dirección de precompile ANDE: 0x00000000000000000000000000000000000000FD"
	@echo "⚙️  Configuración: Type alias pattern (AndeEvmConfig = EthEvmConfig)"
	@echo "🚀 Integración: journal.transfer() para transferencias nativas"
	@echo ""
	@echo "🌐 Endpoints:"
	@echo "  RPC HTTP: http://localhost:8545"
	@echo "  Explorer: http://localhost:4000"
	@echo "  DA Local: http://localhost:7980"
	@echo ""
	@echo "📜 Contratos desplegados (verificar con cast call):"
	@echo "  ANDE Token: Llamar a balanceOf(address) en el contrato desplegado"
	@echo "  Precompile: Usar eth_getBalance en 0x00..FD"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ==========================================
# Build Infrastructure
# ==========================================

# Construir ev-reth con integración ANDE (build desde GitHub en Docker)
build-ev-reth:
	@echo "🔨 Construyendo ev-reth con ANDE Token Duality..."
	@echo "📥 Clone automático desde: https://github.com/AndeLabs/ande-reth"
	@docker build -f Dockerfile.evm -t ande-reth:latest .

# Mostrar versión actual
show-version:
	@echo "📋 AndeChain Version Information"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@if [ -f "VERSION" ]; then \
		echo "🏗️  AndeChain: $$(grep ANDECHAIN_VERSION VERSION | cut -d'=' -f2)"; \
		echo "🔧 Components: $$(grep COMPONENTS_VERSION VERSION | cut -d'=' -f2)"; \
		echo "📦 Build Date: $$(grep BUILD_DATE VERSION | cut -d'=' -f2)"; \
		echo "🔗 Commit: $$(grep COMMIT_HASH VERSION | cut -d'=' -f2)"; \
	else \
		echo "❌ VERSION file not found"; \
	fi
	@echo ""
	@if [ -f "../ev-reth/VERSION" ]; then \
		echo "⚡ ev-reth: $$(grep EV_RETH_VERSION ../ev-reth/VERSION | cut -d'=' -f2)"; \
		echo "🔗 ANDE Integration: $$(grep ANDE_INTEGRATION_VERSION ../ev-reth/VERSION | cut -d'=' -f2)"; \
	else \
		echo "❌ ev-reth VERSION file not found"; \
	fi
	@echo ""
	@if [ -f "../ande-frontend/VERSION" ]; then \
		echo "🌐 Frontend: $$(grep FRONTEND_VERSION ../ande-frontend/VERSION | cut -d'=' -f2)"; \
	else \
		echo "❌ Frontend VERSION file not found"; \
	fi
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Actualizar versión de componente
version-patch:
	@echo "🔄 Bumping patch version..."
	@../scripts/release.sh -c andechain patch

version-minor:
	@echo "🔄 Bumping minor version..."
	@../scripts/release.sh -c andechain minor

version-major:
	@echo "🔄 Bumping major version..."
	@../scripts/release.sh -c andechain major

# Fuerza redeploy de ANDE Token con nueva dirección
redeploy-token:
	@echo "🔄 Forzando redeploy de ANDE Token con nueva dirección..."
	@echo "📊 Obteniendo nonce actual para nueva dirección..."
	@cd contracts && \
		. ./.env && \
		CURRENT_NONCE=$$(cast nonce 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --rpc-url local) && \
		echo "🔢 Nonce actual: $$CURRENT_NONCE (nueva dirección será generada)"; \
		echo "📜 Desplegando nuevo ANDE Token..."; \
		forge script script/DeploySimple.s.sol --rpc-url local --broadcast --legacy --private-key $$PRIVATE_KEY --nonce $$CURRENT_NONCE && \
		echo "✅ Nuevo ANDE Token desplegado exitosamente" || \
		echo "❌ Falló redeploy"; \
		echo ""; \
		echo "📋 Para verificar el nuevo contrato:"; \
		echo "   make health"; \
		echo "   cast call <NEW_ADDRESS> 'name()' --rpc-url local"
