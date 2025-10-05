# ==========================================
# AndeChain Development Makefile
# ==========================================

.PHONY: help start stop reset test coverage security clean deploy-only deploy-ecosystem verify-contracts relayer-only faucet

# Default target
help:
	@echo "AndeChain Development Commands:"
	@echo ""
	@echo "  make start              - Inicia todo el entorno (infra + contracts + relayer + faucet)"
	@echo "  make stop               - Detiene la infraestructura"
	@echo "  make reset              - Reset completo (borra volúmenes)"
	@echo "  make test               - Ejecuta los tests de contratos"
	@echo "  make coverage           - Genera reporte de cobertura"
	@echo "  make security           - Ejecuta análisis de seguridad (Slither)"
	@echo "  make deploy-only        - Solo despliega contratos básicos (requiere infra activa)"
	@echo "  make deploy-ecosystem   - Despliega el ecosistema completo de contratos"
	@echo "  make verify-contracts   - Verifica contratos en Blockscout local"
	@echo "  make relayer-only       - Solo inicia el relayer (requiere contratos desplegados)"
	@echo "  make faucet             - Solo inicia el servidor de faucet"
	@echo "  make clean              - Limpia artifacts de compilación"
	@echo ""

# Inicia el entorno completo con el orden correcto
start:
	@./scripts/start-all.sh

# Detiene la infraestructura
stop:
	@echo "Deteniendo infraestructura..."
	@cd infra && docker compose down

# Reset completo (borra todo)
reset:
	@echo "Reset completo de AndeChain..."
	@cd infra && docker compose down -v
	@rm -rf contracts/out contracts/cache contracts/broadcast
	@echo "Sistema reseteado. Ejecuta 'make start' para comenzar de nuevo."

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
	@cd contracts && slither . --config-file ../slither.config.json || echo "Slither no instalado. Instala con: pip install slither-analyzer"

# Solo deploy (asume que la infraestructura está corriendo)
deploy-only:
	@echo "Desplegando contratos..."
	@cd contracts && \
		export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 && \
		forge script script/DeployBridge.s.sol --tc DeployBridge --rpc-url local --broadcast --legacy

# Solo relayer (asume que los contratos están desplegados)
relayer-only:
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
	@echo "Desplegando ecosistema completo de AndeChain..."
	@cd contracts && \
		export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 && \
		forge script script/DeployEcosystem.s.sol:DeployEcosystem --rpc-url local --broadcast --legacy

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
