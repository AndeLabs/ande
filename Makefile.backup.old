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
	@echo "  make full-start              - 🔥 COMPLETO: Todo automatizado (requisitos + infra + deploy)"
	@echo "  make full-start-with-staking - 🔥 COMPLETO + STAKING: Incluye deployment de staking"
	@echo "  make start                   - Inicia infraestructura (sin verificar requisitos)"
	@echo "  make stop                    - Detiene la infraestructura"
	@echo "  make reset                   - Reset completo (borra volúmenes y artifacts)"
	@echo "  make health                  - Verifica salud del sistema"
	@echo "  make info                    - Muestra información del sistema"
	@echo ""
	@echo "📜 Smart Contracts:"
	@echo "  make test                  - Ejecuta tests de contratos"
	@echo "  make coverage              - Genera reporte de cobertura"
	@echo "  make security              - Análisis de seguridad (Slither)"
	@echo "  make deploy-ecosystem      - Despliega ecosistema completo"
	@echo "  make deploy-staking        - Despliega solo contrato de staking"
	@echo "  make fund-staking          - Fondea contrato de staking con rewards"
	@echo "  make redeploy-token        - Fuerza redeploy de ANDE Token con nueva dirección"
	@echo "  make verify-contracts      - Info sobre verificación en Blockscout"
	@echo ""
	@echo "🔧 Herramientas:"
	@echo "  make build-ev-reth      - Construye ev-reth ANDE desde GitHub"
	@echo "  make relayer            - Inicia relayer de bridge"
	@echo "  make faucet             - Inicia servidor de faucet"
	@echo "  make clean              - Limpia artifacts de compilación"
	@echo ""
	@echo "📊 Monitoreo:"
	@echo "  make start-monitoring   - Inicia Prometheus + Grafana"
	@echo "  make stop-monitoring    - Detiene stack de monitoreo"
	@echo "  make status-monitoring  - Estado del monitoreo"
	@echo "  make metrics            - Muestra métricas en tiempo real"
	@echo "  make status-full        - Estado completo (sistema + monitoreo)"
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
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml up -d --build
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
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml up -d
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
	@echo ""
	@echo "💡 Para desplegar staking: make deploy-staking && make fund-staking"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 🔥 COMANDO COMPLETO CON STAKING - Todo en Uno + Staking
full-start-with-staking: full-start
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🥩 Desplegando Sistema de Staking..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@$(MAKE) deploy-staking
	@echo ""
	@$(MAKE) fund-staking
	@echo ""
	@echo "🎉 AndeChain con Staking está COMPLETAMENTE operativa!"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🌐 RPC:          http://localhost:8545"
	@echo "🔍 Explorer:     http://localhost:4000"
	@echo "💰 ANDE Token:   Desplegado"
	@echo "🥩 Staking:      Desplegado y fondeado"
	@echo "📊 Health Check: make health"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Health check sin output decorativo (para usar en scripts)
health-quiet:
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml ps | grep -q "Up" && echo "✅ Containers running" || echo "❌ Containers not running"
	@curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 | grep -q "0x" && echo "✅ RPC responding" || echo "❌ RPC not responding"

# Detiene la infraestructura
stop:
	@echo "Deteniendo infraestructura ANDE..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml down

# Reset completo (borra todo)
reset:
	@echo "🔄 Reset completo de AndeChain..."
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml down -v
	@rm -rf contracts/out contracts/cache contracts/broadcast
	@echo "✅ Sistema reseteado. Ejecuta 'make start' para comenzar de nuevo."

# Deploy staking contract
deploy-staking:
	@echo "📜 Desplegando AndeNativeStaking..."
	@cd contracts && \
	. ./.env && \
	forge script script/DeployStaking.s.sol:DeployStakingLocal \
		--rpc-url http://localhost:8545 \
		--broadcast \
		--private-key $$PRIVATE_KEY && \
	echo "✅ AndeNativeStaking desplegado exitosamente" || \
	echo "⚠️  Deploy de staking falló"

# Fund staking contract with rewards
fund-staking:
	@echo "💰 Fondeando contrato de staking con rewards..."
	@cd contracts && \
	. ./.env && \
	forge script script/FundStaking.s.sol:FundStakingSmall \
		--rpc-url http://localhost:8545 \
		--broadcast \
		--private-key $$PRIVATE_KEY && \
	echo "✅ Staking fondeado con 30,000 ANDE" || \
	echo "⚠️  Fondeo de staking falló"

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
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml ps
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
	@cd infra && docker compose -f stacks/single-sequencer/docker-compose.yml exec ev-reth-sequencer ev-reth --version 2>/dev/null || echo "ev-reth no disponible"
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

# ==========================================
# Mocha Testnet Deployment Commands
# ==========================================

# Despliega testnet completo en Celestia Mocha
deploy-mocha:
	@echo "🌙 Desplegando AndeChain en Celestia Mocha Testnet..."
	@./scripts/deploy-mocha.sh

# Verifica salud del testnet Mocha
health-mocha:
	@echo "🏥 Verificando salud del testnet Mocha..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "📊 Estado de servicios Mocha:"
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml ps
	@echo ""
	@echo "🌙 Estado de Celestia Mocha:"
	@cd infra && docker compose -f docker-compose.celestia.yml ps
	@echo ""
	@echo "🔗 Conectividad RPC:"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs -I {} echo "Chain ID: {}"
	@echo ""
	@echo "🌙 Red Celestia:"
	@curl -s http://localhost:26657/status | jq -r '.result.node_info.network' | xargs -I {} echo "Network: {}"
	@echo ""
	@echo "📦 Último bloque:"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		http://localhost:8545 | jq -r '.result' | xargs -I {} echo "Block: {}"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detiene testnet Mocha
stop-mocha:
	@echo "🛑 Deteniendo testnet Mocha..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml down
	@cd infra && docker compose -f docker-compose.celestia.yml down

# Limpia testnet Mocha (borra volúmenes)
clean-mocha:
	@echo "🧹 Limpiando testnet Mocha..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml down -v
	@cd infra && docker compose -f docker-compose.celestia.yml down -v
	@docker system prune -f --volumes

# Muestra logs del testnet Mocha
logs-mocha:
	@echo "📝 Mostrando logs del testnet Mocha..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "🚀 AndeChain Services:"
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml logs -f
	@echo ""
	@echo "🌙 Celestia Services:"
	@cd infra && docker compose -f docker-compose.celestia.yml logs -f

# Reinicia servicio específico del testnet Mocha
restart-mocha-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ Especifica SERVICE=nombre_del_servicio"; \
		echo "Servicios disponibles: ev-reth-testnet, single-sequencer-testnet, local-da-testnet, prometheus-testnet, grafana-testnet, celestia-light-client"; \
		exit 1; \
	fi
	@echo "🔄 Reiniciando servicio $(SERVICE)..."
	@if echo "$(SERVICE)" | grep -q "celestia"; then \
		cd infra && docker compose -f docker-compose.celestia.yml restart $(SERVICE); \
	else \
		cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml restart $(SERVICE); \
	fi

# Verifica métricas del testnet Mocha
metrics-mocha:
	@echo "📊 Verificando métricas del testnet Mocha..."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000 (admin/ande_testnet_2025)"
	@echo "AndeChain Metrics: http://localhost:9001/metrics"
	@echo "Sequencer Metrics: http://localhost:26660/metrics"
	@echo "Celestia Exporter: http://localhost:9100/metrics"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Despliega contratos en testnet Mocha
deploy-contracts-mocha:
	@echo "📜 Desplegando contratos en testnet Mocha..."
	@cd contracts && \
		if [ ! -f ".env.mocha" ]; then \
			echo "Creando .env.mocha..."; \
			echo "PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" > .env.mocha; \
			echo "RPC_URL=http://localhost:8545" >> .env.mocha; \
			echo "CHAIN_ID=1234" >> .env.mocha; \
		fi && \
		source .env.mocha && \
		forge script script/DeploySimple.s.sol --rpc-url $$RPC_URL --broadcast --legacy --private-key $$PRIVATE_KEY

# ==========================================
# Testnet Deployment Commands (Legacy)
# ==========================================

# Despliega testnet completo con MEV y ejecución paralela
deploy-testnet:
	@echo "🚀 Desplegando AndeChain Testnet con MEV y ejecución paralela..."
	@./scripts/deploy-testnet.sh

# Verifica salud del testnet
health-testnet:
	@echo "🏥 Verificando salud del testnet..."
	@./scripts/testnet-health-check.sh

# Detiene testnet
stop-testnet:
	@echo "🛑 Deteniendo testnet..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml down

# Limpia testnet (borra volúmenes)
clean-testnet:
	@echo "🧹 Limpiando testnet..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml down -v
	@docker system prune -f --volumes

# Muestra logs del testnet
logs-testnet:
	@echo "📝 Mostrando logs del testnet..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml logs -f

# Reinicia servicio específico del testnet
restart-testnet-service:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ Especifica SERVICE=nombre_del_servicio"; \
		echo "Servicios disponibles: ev-reth-testnet, single-sequencer-testnet, local-da-testnet, prometheus-testnet, grafana-testnet"; \
		exit 1; \
	fi
	@echo "🔄 Reiniciando servicio $(SERVICE)..."
	@cd infra/stacks/single-sequencer && docker compose -f docker-compose.testnet.yml restart $(SERVICE)

# Verifica métricas del testnet
metrics-testnet:
	@echo "📊 Verificando métricas del testnet..."
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000 (admin/ande_testnet_2025)"
	@echo "MEV Metrics: http://localhost:9002/metrics"
	@echo "Parallel Metrics: http://localhost:9002/parallel/metrics"

# Configura dashboards de Grafana
setup-dashboards:
	@echo "📊 Configurando dashboards de Grafana..."
	@./scripts/setup-grafana-dashboards.sh

# Análisis de optimización de gas
gas-analysis:
	@echo "⛽ Ejecutando análisis de optimización de gas..."
	@./scripts/gas-optimization.sh

# Genera reporte de gas
gas-report:
	@echo "📊 Generando reporte de gas..."
	@cd contracts && forge test --gas-report | grep -A 50 -B 5 "MEV\|VotingEscrow" || echo "No MEV contracts found"

# Optimización de contratos
gas-optimize:
	@echo "🔧 Ejecutando optimización de gas..."
	@cd contracts && forge build --optimize --optimizer-runs 20000
	@echo "✅ Contratos optimizados con --optimizer-runs 20000"

# Despliegue de ZK Lazybridging
deploy-zk-lazybridging:
	@echo "🔐 Desplegando ZK Lazybridging..."
	@./scripts/deploy-zk-lazybridging.sh --network testnet --rpc-url http://localhost:8545

# Despliegue de ZK Lazybridging (mainnet)
deploy-zk-lazybridging-mainnet:
	@echo "🔐 Desplegando ZK Lazybridging a mainnet..."
	@./scripts/deploy-zk-lazybridging.sh --network mainnet --rpc-url $(MAINNET_RPC_URL) --private-key $(MAINNET_PRIVATE_KEY)

# Infraestructura de ZK Lazybridging
start-zk-infrastructure:
	@echo "🚀 Iniciando infraestructura ZK Lazybridging..."
	@cd infra && docker-compose -f docker-compose.celestia.yml up -d
	@cd infra && docker-compose -f docker-compose.prover.yml up -d
	@cd infra && docker-compose -f docker-compose.relayer.yml up -d
	@echo "✅ Infraestructura ZK Lazybridging iniciada"

# Detener infraestructura ZK
stop-zk-infrastructure:
	@echo "🛑 Deteniendo infraestructura ZK Lazybridging..."
	@cd infra && docker-compose -f docker-compose.relayer.yml down
	@cd infra && docker-compose -f docker-compose.prover.yml down
	@cd infra && docker-compose -f docker-compose.celestia.yml down
	@echo "✅ Infraestructura ZK Lazybridging detenida"

# Salud de ZK Lazybridging
health-zk-lazybridging:
	@echo "🏥 Verificando salud de ZK Lazybridging..."
	@curl -s http://localhost:8080/health || echo "❌ ZK Prover no responde"
	@curl -s http://localhost:26657/status || echo "❌ Celestia Light Client no responde"
	@curl -s http://localhost:3000/health || echo "❌ IBC Relayer no responde"
	@docker ps | grep -E "(zk-prover|celestia|ibc-relayer)" || echo "❌ Contenedores no corriendo"

# ==========================================
# Monitoring Commands
# ==========================================

# Inicia el stack de monitoreo completo
start-monitoring:
	@echo "📊 Iniciando stack de monitoreo..."
	@./start-monitoring.sh start

# Detiene el stack de monitoreo
stop-monitoring:
	@echo "🛑 Deteniendo stack de monitoreo..."
	@./start-monitoring.sh stop

# Reinicia el stack de monitoreo
restart-monitoring:
	@echo "🔄 Reiniciando stack de monitoreo..."
	@./start-monitoring.sh restart

# Muestra el estado del stack de monitoreo
status-monitoring:
	@echo "📊 Estado del stack de monitoreo..."
	@./start-monitoring.sh status

# Muestra logs del stack de monitoreo
logs-monitoring:
	@echo "📝 Mostrando logs del stack de monitoreo..."
	@./start-monitoring.sh logs

# Verifica targets de Prometheus
targets-monitoring:
	@echo "🎯 Verificando targets de Prometheus..."
	@./start-monitoring.sh targets

# Muestra métricas en tiempo real
metrics:
	@echo "📊 Mostrando métricas de AndeChain..."
	@./monitor-logs.sh metrics

# Muestra el estado completo del sistema con monitoreo
status-full:
	@echo "📊 Estado completo del sistema AndeChain + Monitoreo..."
	@./monitor-logs.sh status
