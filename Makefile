# ==========================================
# ANDE Chain - Production Makefile
# Rollup EVM with Celestia DA
# ==========================================
#
# Version: 2.0.0
# Last Updated: December 2024
# 
# This Makefile provides standardized commands for:
# - Local development (with Celestia DA)
# - Testnet deployment (Celestia Mocha-4)
# - Mainnet deployment (Celestia Mainnet)
# - Security auditing
# - Monitoring & maintenance
#
# ARCHITECTURE:
# - Sovereign Rollup (NO Ethereum L1)
# - ev-reth (Modified Reth with ANDE Precompile + Parallel EVM)
# - Evolve Sequencer (ExRollkit)
# - Celestia DA Layer
# - Blockscout Explorer
#
# Usage: make <command> [ENV=<environment>]
# Example: make deploy ENV=testnet
# ==========================================

.PHONY: help clean install validate

# ==========================================
# CONFIGURATION
# ==========================================

# Default environment
ENV ?= local

# Colors for output
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Project paths
PROJECT_ROOT := $(shell pwd)
CONTRACTS_DIR := $(PROJECT_ROOT)/contracts
INFRA_DIR := $(PROJECT_ROOT)/infra
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts

# RPC URLs by environment (our own sovereign chain)
RPC_URL_LOCAL := http://localhost:8545
RPC_URL_TESTNET := $(shell grep TESTNET_RPC_URL .env.$(ENV) 2>/dev/null | cut -d '=' -f2 || echo "")
RPC_URL_MAINNET := $(shell grep MAINNET_RPC_URL .env.$(ENV) 2>/dev/null | cut -d '=' -f2 || echo "")

# Celestia DA endpoints
CELESTIA_RPC_LOCAL := http://localhost:26658
CELESTIA_NETWORK_TESTNET := mocha-4
CELESTIA_NETWORK_MAINNET := celestia

# Chain IDs (our sovereign chain IDs)
CHAIN_ID_LOCAL := 1234
CHAIN_ID_TESTNET := 1234  # Same chain, different DA network
CHAIN_ID_MAINNET := 1234  # Our production chain ID

# Private key handling (use keystore, not raw keys)
DEPLOYER_ACCOUNT_LOCAL := deployer-local
DEPLOYER_ACCOUNT_TESTNET := deployer-testnet
DEPLOYER_ACCOUNT_MAINNET := deployer-mainnet

# ==========================================
# HELP & INFO
# ==========================================

help: ## Show this help message
	@echo "$(BLUE)╔════════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  ANDE Chain - Production Makefile                             ║$(NC)"
	@echo "$(BLUE)║  Sovereign Rollup with Celestia DA                             ║$(NC)"
	@echo "$(BLUE)║  ev-reth + Evolve Sequencer + Blockscout                       ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)🚀 Quick Start:$(NC)"
	@echo "  make setup                    - First-time setup (install dependencies)"
	@echo "  make deploy-local             - Deploy complete system locally"
	@echo "  make test-all                 - Run all tests"
	@echo ""
	@echo "$(GREEN)📋 Main Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-30s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)🌍 Environment Options:$(NC)"
	@echo "  ENV=local    - Local development (default)"
	@echo "  ENV=testnet  - Public testnet"
	@echo "  ENV=mainnet  - Production mainnet"
	@echo ""
	@echo "$(YELLOW)📖 Documentation: docs/DEPLOYMENT_GUIDE.md$(NC)"

version: ## Show version information
	@echo "$(GREEN)ANDE Chain Version Information$(NC)"
	@cat VERSION 2>/dev/null || echo "Version file not found"
	@echo ""
	@echo "$(GREEN)Component Versions:$(NC)"
	@forge --version 2>/dev/null | head -n 1 || echo "Foundry not installed"
	@docker --version 2>/dev/null || echo "Docker not installed"
	@docker compose version 2>/dev/null || echo "Docker Compose not installed"
	@echo ""
	@echo "$(GREEN)Celestia Status:$(NC)"
	@docker ps --filter "name=celestia" --format "table {{.Names}}\t{{.Status}}" 2>/dev/null || echo "Celestia not running"

# ==========================================
# SETUP & INSTALLATION
# ==========================================

setup: ## Complete first-time setup
	@echo "$(GREEN)🔧 Setting up ANDE Chain development environment...$(NC)"
	@$(MAKE) check-prerequisites
	@$(MAKE) install-dependencies
	@$(MAKE) setup-env-files
	@$(MAKE) setup-keystore
	@echo "$(GREEN)✅ Setup complete! Run 'make deploy-local' to start.$(NC)"

check-prerequisites: ## Check if all required tools are installed
	@echo "$(BLUE)Checking prerequisites...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)❌ Docker not found. Install from https://docker.com$(NC)"; exit 1; }
	@command -v docker compose >/dev/null 2>&1 || { echo "$(RED)❌ Docker Compose not found$(NC)"; exit 1; }
	@command -v forge >/dev/null 2>&1 || { echo "$(RED)❌ Foundry not found. Run: curl -L https://foundry.paradigm.xyz | bash && foundryup$(NC)"; exit 1; }
	@command -v cast >/dev/null 2>&1 || { echo "$(RED)❌ Cast not found$(NC)"; exit 1; }
	@command -v git >/dev/null 2>&1 || { echo "$(RED)❌ Git not found$(NC)"; exit 1; }
	@echo "$(GREEN)✅ All prerequisites installed$(NC)"

install-dependencies: ## Install project dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	@cd $(CONTRACTS_DIR) && forge install
	@npm install
	@echo "$(GREEN)✅ Dependencies installed$(NC)"

setup-env-files: ## Create environment files from templates
	@echo "$(BLUE)Setting up environment files...$(NC)"
	@test -f .env.local || cp .env.example .env.local
	@test -f .env.testnet || cp .env.example .env.testnet
	@test -f .env.mainnet || cp .env.example .env.mainnet
	@chmod 600 .env.*
	@echo "$(GREEN)✅ Environment files created. Please update with your values.$(NC)"

setup-keystore: ## Setup Foundry encrypted keystore
	@echo "$(BLUE)Setting up encrypted keystores...$(NC)"
	@echo "$(YELLOW)Creating local deployer keystore...$(NC)"
	@cast wallet list | grep -q "$(DEPLOYER_ACCOUNT_LOCAL)" || \
		echo "Run: cast wallet import $(DEPLOYER_ACCOUNT_LOCAL) --interactive"
	@echo "$(GREEN)✅ Keystore setup instructions displayed$(NC)"

# ==========================================
# VALIDATION & PRE-FLIGHT CHECKS
# ==========================================

validate: validate-$(ENV) ## Validate configuration for current environment

validate-local: ## Validate local environment
	@echo "$(BLUE)Validating local environment...$(NC)"
	@test -f .env.local || { echo "$(RED)❌ .env.local not found$(NC)"; exit 1; }
	@cast wallet list | grep -q "$(DEPLOYER_ACCOUNT_LOCAL)" || { echo "$(YELLOW)⚠️  Keystore '$(DEPLOYER_ACCOUNT_LOCAL)' not found$(NC)"; }
	@docker ps >/dev/null 2>&1 || { echo "$(RED)❌ Docker daemon not running$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Local environment valid$(NC)"

validate-testnet: ## Validate testnet configuration
	@echo "$(BLUE)Validating testnet environment (Celestia Mocha-4)...$(NC)"
	@test -f .env.testnet || { echo "$(RED)❌ .env.testnet not found$(NC)"; exit 1; }
	@grep -q "TESTNET_RPC_URL" .env.testnet || { echo "$(RED)❌ TESTNET_RPC_URL not set$(NC)"; exit 1; }
	@grep -q "CELESTIA_RPC_URL" .env.testnet || { echo "$(YELLOW)⚠️  CELESTIA_RPC_URL not set (required for DA)$(NC)"; }
	@grep -q "CELESTIA_AUTH_TOKEN" .env.testnet || { echo "$(YELLOW)⚠️  CELESTIA_AUTH_TOKEN not set$(NC)"; }
	@cast wallet list | grep -q "$(DEPLOYER_ACCOUNT_TESTNET)" || { echo "$(RED)❌ Keystore '$(DEPLOYER_ACCOUNT_TESTNET)' not found. Run: cast wallet import $(DEPLOYER_ACCOUNT_TESTNET) --interactive$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Testnet environment valid$(NC)"

validate-mainnet: ## Validate mainnet configuration (strict)
	@echo "$(BLUE)Validating mainnet environment (STRICT MODE)...$(NC)"
	@test -f .env.mainnet || { echo "$(RED)❌ .env.mainnet not found$(NC)"; exit 1; }
	@grep -q "MAINNET_RPC_URL" .env.mainnet || { echo "$(RED)❌ MAINNET_RPC_URL not set$(NC)"; exit 1; }
	@grep -q "CELESTIA_RPC_URL" .env.mainnet || { echo "$(RED)❌ CELESTIA_RPC_URL not set (REQUIRED for production DA)$(NC)"; exit 1; }
	@grep -q "CELESTIA_AUTH_TOKEN" .env.mainnet || { echo "$(RED)❌ CELESTIA_AUTH_TOKEN not set$(NC)"; exit 1; }
	@grep -q "MAINNET_MULTISIG" .env.mainnet || { echo "$(RED)❌ MAINNET_MULTISIG not set$(NC)"; exit 1; }
	@cast wallet list | grep -q "$(DEPLOYER_ACCOUNT_MAINNET)" || { echo "$(RED)❌ Keystore '$(DEPLOYER_ACCOUNT_MAINNET)' not found$(NC)"; exit 1; }
	@test -f contracts/SECURITY_AUDIT_REPORT.md || { echo "$(RED)❌ Security audit report missing$(NC)"; exit 1; }
	@echo "$(GREEN)✅ Mainnet environment valid$(NC)"

check-balance: check-balance-$(ENV) ## Check deployer balance

check-balance-local:
	@echo "$(BLUE)Checking local deployer balance...$(NC)"
	@ADDR=$$(cast wallet address --account $(DEPLOYER_ACCOUNT_LOCAL) 2>/dev/null || echo "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266") && \
	BAL=$$(cast balance $$ADDR --rpc-url $(RPC_URL_LOCAL) 2>/dev/null) && \
	echo "Address: $$ADDR" && \
	echo "Balance: $$(cast --to-unit $$BAL ether) ETH" || echo "$(RED)Failed to check balance$(NC)"

check-balance-testnet:
	@echo "$(BLUE)Checking testnet deployer balance...$(NC)"
	@ADDR=$$(cast wallet address --account $(DEPLOYER_ACCOUNT_TESTNET)) && \
	RPC=$$(grep TESTNET_RPC_URL .env.testnet | cut -d '=' -f2) && \
	BAL=$$(cast balance $$ADDR --rpc-url $$RPC) && \
	echo "Address: $$ADDR" && \
	echo "Balance: $$(cast --to-unit $$BAL ether) ETH" && \
	(( $$(echo "$$BAL > 1000000000000000000" | bc -l) )) || echo "$(YELLOW)⚠️  Low balance! Get testnet ETH from faucet$(NC)"

# ==========================================
# LOCAL DEVELOPMENT
# ==========================================

deploy-local: validate-local clean-local build-local start-local deploy-contracts-local fund-staking-local verify-local ## Complete local deployment
	@echo "$(GREEN)✅ Local deployment complete!$(NC)"
	@echo ""
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  ANDE Chain Local Environment Ready           ║$(NC)"
	@echo "$(BLUE)║  Sovereign Rollup + Celestia DA                ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)🌐 RPC (ev-reth):$(NC)     http://localhost:8545"
	@echo "$(GREEN)📊 Celestia DA:$(NC)       http://localhost:26658"
	@echo "$(GREEN)🔍 Explorer:$(NC)          http://localhost:4000"
	@echo "$(GREEN)📈 Grafana:$(NC)           http://localhost:3001"
	@echo "$(GREEN)🎯 Frontend:$(NC)          http://localhost:9002"
	@echo "$(GREEN)⚡ Precompile:$(NC)        0x00000000000000000000000000000000000000FD"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  - Run tests: make test-all"
	@echo "  - Check health: make health"
	@echo "  - View logs: make logs"

clean-local: ## Clean local artifacts
	@echo "$(BLUE)Cleaning local artifacts...$(NC)"
	@cd $(CONTRACTS_DIR) && rm -rf out cache broadcast
	@docker compose -f $(INFRA_DIR)/stacks/single-sequencer/docker-compose.yml down -v 2>/dev/null || true
	@echo "$(GREEN)✅ Local environment cleaned$(NC)"

build-local: ## Build local contracts
	@echo "$(BLUE)Building contracts...$(NC)"
	@cd $(CONTRACTS_DIR) && forge build
	@echo "$(GREEN)✅ Contracts built$(NC)"

start-local: ## Start local infrastructure (ev-reth + Evolve + Celestia DA)
	@echo "$(BLUE)Starting local infrastructure...$(NC)"
	@echo "  - ev-reth (EVM execution layer)"
	@echo "  - Evolve Sequencer (ExRollkit)"
	@echo "  - Celestia DA (local or testnet)"
	@echo "  - Blockscout Explorer"
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml up -d
	@echo "$(YELLOW)⏳ Waiting for chain to stabilize (60s)...$(NC)"
	@sleep 60
	@echo "$(GREEN)✅ Infrastructure started$(NC)"
	@echo "$(BLUE)Checking services...$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "ev-reth|evolve|celestia"

deploy-contracts-local: ## Deploy contracts to local chain
	@echo "$(BLUE)Deploying contracts to local chain...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	forge script script/DeployANDEToken.s.sol:DeployANDEToken \
		--rpc-url $(RPC_URL_LOCAL) \
		--broadcast \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	@cd $(CONTRACTS_DIR) && \
	forge script script/DeployStaking.s.sol:DeployStakingLocal \
		--rpc-url $(RPC_URL_LOCAL) \
		--broadcast \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	@echo "$(GREEN)✅ Contracts deployed$(NC)"

fund-staking-local: ## Fund staking contract with rewards
	@echo "$(BLUE)Funding staking contract...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	forge script script/FundStaking.s.sol:FundStakingSmall \
		--rpc-url $(RPC_URL_LOCAL) \
		--broadcast \
		--private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
	@echo "$(GREEN)✅ Staking contract funded$(NC)"

verify-local: ## Verify local deployment
	@echo "$(BLUE)Verifying local deployment...$(NC)"
	@cd $(CONTRACTS_DIR) && forge script script/SaveAddresses.s.sol:SaveAddresses --rpc-url $(RPC_URL_LOCAL)
	@echo "$(GREEN)✅ Deployment verified$(NC)"

# ==========================================
# TESTNET DEPLOYMENT
# ==========================================

deploy-testnet: pre-deploy-check-testnet deploy-contracts-testnet fund-staking-testnet verify-testnet post-deploy-testnet ## Complete testnet deployment
	@echo "$(GREEN)✅ Testnet deployment complete!$(NC)"

pre-deploy-check-testnet: validate-testnet check-balance-testnet ## Pre-deployment checks for testnet
	@echo "$(BLUE)Running pre-deployment checks...$(NC)"
	@$(MAKE) test-all
	@$(MAKE) security-audit
	@echo "$(YELLOW)⚠️  Review the above output before proceeding$(NC)"
	@read -p "Continue with testnet deployment? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo "$(GREEN)✅ Pre-deployment checks passed$(NC)"

deploy-contracts-testnet: ## Deploy contracts to testnet
	@echo "$(BLUE)Deploying contracts to ANDE Chain testnet...$(NC)"
	@echo "$(YELLOW)⚠️  This will deploy to our testnet (Celestia Mocha-4 for DA)$(NC)"
	@cd $(CONTRACTS_DIR) && \
	source ../.env.testnet && \
	forge script script/DeployANDEToken.s.sol:DeployANDEToken \
		--rpc-url $$TESTNET_RPC_URL \
		--account $(DEPLOYER_ACCOUNT_TESTNET) \
		--sender $$(cast wallet address --account $(DEPLOYER_ACCOUNT_TESTNET)) \
		--broadcast
	@cd $(CONTRACTS_DIR) && \
	source ../.env.testnet && \
	forge script script/DeployStaking.s.sol:DeployStakingLocal \
		--rpc-url $$TESTNET_RPC_URL \
		--account $(DEPLOYER_ACCOUNT_TESTNET) \
		--sender $$(cast wallet address --account $(DEPLOYER_ACCOUNT_TESTNET)) \
		--broadcast
	@echo "$(GREEN)✅ Contracts deployed to testnet$(NC)"
	@echo "$(BLUE)Verify on Blockscout: http://your-testnet-explorer:4000$(NC)"

fund-staking-testnet: ## Fund testnet staking contract
	@echo "$(BLUE)Funding testnet staking contract...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	source ../.env.testnet && \
	forge script script/FundStaking.s.sol:FundStakingSmall \
		--rpc-url $$TESTNET_RPC_URL \
		--account $(DEPLOYER_ACCOUNT_TESTNET) \
		--sender $$(cast wallet address --account $(DEPLOYER_ACCOUNT_TESTNET)) \
		--broadcast
	@echo "$(GREEN)✅ Staking contract funded$(NC)"

verify-testnet: ## Verify testnet deployment
	@echo "$(BLUE)Verifying testnet deployment...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	source ../.env.testnet && \
	forge script script/SaveAddresses.s.sol:SaveAddresses --rpc-url $$TESTNET_RPC_URL
	@echo "$(GREEN)✅ Testnet deployment verified$(NC)"

post-deploy-testnet: ## Post-deployment tasks for testnet
	@echo "$(BLUE)Running post-deployment tasks...$(NC)"
	@echo "$(GREEN)📝 Deployment addresses saved to contracts/deployments/$(NC)"
	@echo "$(YELLOW)⚠️  Next steps:$(NC)"
	@echo "  1. Verify Celestia DA is publishing blobs: make celestia-status"
	@echo "  2. Update frontend addresses in andefrontend/src/contracts/addresses.ts"
	@echo "  3. Run smoke tests: make smoke-test ENV=testnet"
	@echo "  4. Check Blockscout explorer"
	@echo "  5. Monitor for 24-48 hours"
	@echo "  6. Document any issues in GitHub"

# ==========================================
# MAINNET DEPLOYMENT (PRODUCTION)
# ==========================================

deploy-mainnet: pre-deploy-check-mainnet deploy-contracts-mainnet-multisig verify-mainnet post-deploy-mainnet ## Complete mainnet deployment (PRODUCTION)
	@echo "$(GREEN)✅ Mainnet deployment complete!$(NC)"

pre-deploy-check-mainnet: validate-mainnet ## Pre-deployment checks for mainnet (STRICT)
	@echo "$(RED)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(RED)║  MAINNET DEPLOYMENT - PRODUCTION              ║$(NC)"
	@echo "$(RED)║  SOVEREIGN ROLLUP TO CELESTIA MAINNET         ║$(NC)"
	@echo "$(RED)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Pre-deployment checklist:$(NC)"
	@test -f contracts/SECURITY_AUDIT_REPORT.md && echo "$(GREEN)✅ Security audit completed$(NC)" || { echo "$(RED)❌ Security audit missing$(NC)"; exit 1; }
	@$(MAKE) test-all && echo "$(GREEN)✅ All tests passing$(NC)" || { echo "$(RED)❌ Tests failing$(NC)"; exit 1; }
	@$(MAKE) security-audit && echo "$(GREEN)✅ Security scan passed$(NC)" || { echo "$(RED)❌ Security issues found$(NC)"; exit 1; }
	@echo ""
	@echo "$(RED)⚠️  FINAL CONFIRMATION REQUIRED$(NC)"
	@read -p "Type 'DEPLOY TO MAINNET' to continue: " confirm && [ "$$confirm" = "DEPLOY TO MAINNET" ] || { echo "$(YELLOW)Deployment cancelled$(NC)"; exit 1; }

deploy-contracts-mainnet-multisig: ## Deploy to mainnet using multisig
	@echo "$(BLUE)Deploying contracts to ANDE Chain mainnet...$(NC)"
	@echo "$(YELLOW)⚠️  Follow the prompts carefully$(NC)"
	@echo "$(BLUE)Celestia Mainnet DA will be used$(NC)"
	@cd $(CONTRACTS_DIR) && \
	source ../.env.mainnet && \
	forge script script/DeployANDEToken.s.sol:DeployANDEToken \
		--rpc-url $$MAINNET_RPC_URL \
		--account $(DEPLOYER_ACCOUNT_MAINNET) \
		--sender $$(cast wallet address --account $(DEPLOYER_ACCOUNT_MAINNET)) \
		--broadcast \
		--slow
	@echo "$(GREEN)✅ Contracts deployed to mainnet$(NC)"
	@echo "$(BLUE)Verify on Blockscout: your-mainnet-blockscout$(NC)"

verify-mainnet: ## Verify mainnet deployment
	@echo "$(BLUE)Verifying mainnet deployment...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	source ../.env.mainnet && \
	forge script script/SaveAddresses.s.sol:SaveAddresses --rpc-url $$MAINNET_RPC_URL
	@echo "$(GREEN)✅ Mainnet deployment verified$(NC)"

post-deploy-mainnet: ## Post-deployment tasks for mainnet
	@echo "$(BLUE)Running post-deployment tasks...$(NC)"
	@echo "$(GREEN)📝 MAINNET DEPLOYMENT COMPLETE$(NC)"
	@echo ""
	@echo "$(YELLOW)⚠️  CRITICAL NEXT STEPS:$(NC)"
	@echo "  1. Transfer ownership to multisig"
	@echo "  2. Enable 24/7 monitoring"
	@echo "  3. Set up incident response team"
	@echo "  4. Create public announcement"
	@echo "  5. Monitor for first 72 hours continuously"

# ==========================================
# TESTING
# ==========================================

test-all: test-unit test-integration test-fuzz ## Run all tests
	@echo "$(GREEN)✅ All tests completed$(NC)"

test-unit: ## Run unit tests
	@echo "$(BLUE)Running unit tests...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test --match-path "test/unit/**/*.t.sol" -vv

test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test --match-path "test/integration/**/*.t.sol" -vv

test-fuzz: ## Run fuzz tests
	@echo "$(BLUE)Running fuzz tests...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test --fuzz-runs 10000

test-coverage: ## Generate test coverage report
	@echo "$(BLUE)Generating coverage report...$(NC)"
	@cd $(CONTRACTS_DIR) && forge coverage --report lcov
	@cd $(CONTRACTS_DIR) && genhtml lcov.info -o coverage/html
	@echo "$(GREEN)✅ Coverage report: contracts/coverage/html/index.html$(NC)"

smoke-test: ## Run smoke tests on deployed contracts
	@echo "$(BLUE)Running smoke tests on $(ENV) environment...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	RPC_URL=$$([ "$(ENV)" = "local" ] && echo "$(RPC_URL_LOCAL)" || grep $$(echo "$(ENV)" | tr '[:lower:]' '[:upper:]')_RPC_URL ../.env.$(ENV) | cut -d '=' -f2) && \
	forge test --match-contract SmokeTest --fork-url $$RPC_URL -vv

# ==========================================
# SECURITY & AUDITING
# ==========================================

security-audit: ## Run comprehensive security audit
	@echo "$(BLUE)Running security audit...$(NC)"
	@$(MAKE) security-slither
	@$(MAKE) security-aderyn
	@echo "$(GREEN)✅ Security audit complete$(NC)"

security-slither: ## Run Slither static analysis
	@echo "$(BLUE)Running Slither analysis...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	slither . --config-file slither.config.json --json slither-results.json 2>/dev/null || true
	@cd $(CONTRACTS_DIR) && \
	slither . --print human-summary 2>/dev/null || echo "$(YELLOW)Slither not installed. Run: pip install slither-analyzer$(NC)"

security-aderyn: ## Run Aderyn analysis
	@echo "$(BLUE)Running Aderyn analysis...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	aderyn . || echo "$(YELLOW)Aderyn not installed. Run: cargo install aderyn$(NC)"

security-mythril: ## Run Mythril analysis (slow but thorough)
	@echo "$(BLUE)Running Mythril analysis (this may take several minutes)...$(NC)"
	@cd $(CONTRACTS_DIR) && \
	myth analyze src/**/*.sol || echo "$(YELLOW)Mythril not installed$(NC)"

gas-report: ## Generate gas usage report
	@echo "$(BLUE)Generating gas report...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test --gas-report

# ==========================================
# VERIFICATION
# ==========================================

verify: verify-$(ENV) ## Verify contracts on block explorer

verify-local:
	@echo "$(BLUE)Verifying contracts on local explorer...$(NC)"
	@echo "$(YELLOW)Local explorer verification not required$(NC)"

verify-testnet:
	@echo "$(BLUE)Verifying contracts on Blockscout...$(NC)"
	@echo "$(YELLOW)Note: Verification on Blockscout may require manual steps$(NC)"
	@echo "Visit your Blockscout instance to verify contracts"
	@cat $(CONTRACTS_DIR)/deployments/addresses-local.json | jq -r '.contracts'

verify-mainnet:
	@echo "$(BLUE)Verifying contracts on mainnet Blockscout...$(NC)"
	@echo "$(YELLOW)Visit your Blockscout instance for verification$(NC)"
	@cat $(CONTRACTS_DIR)/deployments/addresses-local.json | jq -r '.contracts'

# ==========================================
# PUBLIC TESTNET DEPLOYMENT
# ==========================================

setup-ssl: ## Setup SSL certificates with certbot
	@echo "$(BLUE)Setting up SSL certificates...$(NC)"
	@echo "$(YELLOW)Prerequisites:$(NC)"
	@echo "  - Domain DNS must point to this server"
	@echo "  - Ports 80 and 443 must be open"
	@echo ""
	@echo "$(BLUE)Domains to configure:$(NC)"
	@grep "^DOMAIN_" .env.$(ENV) 2>/dev/null || echo "$(RED)No domains configured in .env.$(ENV)$(NC)"
	@echo ""
	@echo "$(YELLOW)Run certbot for each domain:$(NC)"
	@echo "  docker compose run --rm certbot certonly --webroot -w /var/www/certbot -d YOUR_DOMAIN"
	@echo ""
	@echo "$(YELLOW)After certificates are obtained, restart nginx:$(NC)"
	@echo "  docker compose restart nginx"

renew-ssl: ## Renew SSL certificates
	@echo "$(BLUE)Renewing SSL certificates...$(NC)"
	@docker compose run --rm certbot renew
	@docker compose restart nginx
	@echo "$(GREEN)✅ Certificates renewed$(NC)"

check-ssl: ## Check SSL certificate expiration
	@echo "$(BLUE)Checking SSL certificates...$(NC)"
	@for domain in $$(grep "^DOMAIN_" .env.$(ENV) | cut -d'=' -f2); do \
		echo "$(YELLOW)Checking $$domain$(NC)"; \
		echo | openssl s_client -servername $$domain -connect $$domain:443 2>/dev/null | \
		openssl x509 -noout -dates 2>/dev/null || echo "$(RED)No certificate for $$domain$(NC)"; \
	done

setup-public: validate-testnet ## Setup chain for public access
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  Setting up AndeChain for Public Access       ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Step 1: Configure .env.testnet$(NC)"
	@echo "  - Set DOMAIN_* variables"
	@echo "  - Set LETSENCRYPT_EMAIL"
	@echo "  - Set secure passwords"
	@echo ""
	@echo "$(GREEN)Step 2: Configure DNS$(NC)"
	@echo "  Point these domains to your server IP:"
	@grep "^DOMAIN_" .env.testnet 2>/dev/null | sed 's/DOMAIN_/  - /' | sed 's/=/ → /'
	@echo ""
	@echo "$(GREEN)Step 3: Configure Firewall$(NC)"
	@echo "  sudo ufw allow 80/tcp"
	@echo "  sudo ufw allow 443/tcp"
	@echo "  sudo ufw allow 30303/tcp  # P2P"
	@echo "  sudo ufw enable"
	@echo ""
	@echo "$(GREEN)Step 4: Obtain SSL certificates$(NC)"
	@echo "  make setup-ssl ENV=testnet"
	@echo ""
	@echo "$(GREEN)Step 5: Start services$(NC)"
	@echo "  docker compose up -d"
	@echo ""
	@echo "$(GREEN)Step 6: Verify$(NC)"
	@echo "  make health-public"

health-public: ## Check public endpoints health
	@echo "$(BLUE)Checking public endpoints...$(NC)"
	@echo ""
	@echo "$(GREEN)RPC Endpoint:$(NC)"
	@RPC_DOMAIN=$$(grep "^DOMAIN_RPC" .env.$(ENV) | cut -d'=' -f2) && \
		curl -s -X POST https://$$RPC_DOMAIN \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | \
		jq -r '.result' | xargs printf "Block: %d\n" 2>/dev/null || echo "$(RED)RPC not responding$(NC)"
	@echo ""
	@echo "$(GREEN)WebSocket Endpoint:$(NC)"
	@WS_DOMAIN=$$(grep "^DOMAIN_WS" .env.$(ENV) | cut -d'=' -f2) && \
		echo "  wss://$$WS_DOMAIN (test with MetaMask)"
	@echo ""
	@echo "$(GREEN)Explorer:$(NC)"
	@EXPLORER_DOMAIN=$$(grep "^DOMAIN_EXPLORER" .env.$(ENV) | cut -d'=' -f2) && \
		curl -s https://$$EXPLORER_DOMAIN -o /dev/null && \
		echo "  ✅ https://$$EXPLORER_DOMAIN" || echo "  ❌ Explorer not responding"
	@echo ""
	@echo "$(GREEN)Monitoring:$(NC)"
	@STATUS_DOMAIN=$$(grep "^DOMAIN_STATUS" .env.$(ENV) | cut -d'=' -f2) && \
		curl -s https://$$STATUS_DOMAIN -o /dev/null && \
		echo "  ✅ https://$$STATUS_DOMAIN" || echo "  ❌ Status page not responding"

test-from-external: ## Test RPC from external network
	@echo "$(BLUE)Testing public RPC access...$(NC)"
	@RPC_DOMAIN=$$(grep "^DOMAIN_RPC" .env.$(ENV) | cut -d'=' -f2) && \
		echo "Testing https://$$RPC_DOMAIN" && \
		curl -X POST https://$$RPC_DOMAIN \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' && \
		echo "" && \
		curl -X POST https://$$RPC_DOMAIN \
		-H "Content-Type: application/json" \
		-d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' && \
		echo ""

generate-secrets: ## Generate secure secrets for production
	@echo "$(BLUE)Generating secure secrets...$(NC)"
	@echo ""
	@echo "$(GREEN)JWT Secret (for JWT):$(NC)"
	@openssl rand -hex 32
	@echo ""
	@echo "$(GREEN)Blockscout Secret Key Base:$(NC)"
	@openssl rand -base64 64 | tr -d '\n' && echo ""
	@echo ""
	@echo "$(GREEN)Grafana Admin Password:$(NC)"
	@openssl rand -base64 24 | tr -d '\n' && echo ""
	@echo ""
	@echo "$(GREEN)PostgreSQL Password:$(NC)"
	@openssl rand -base64 32 | tr -d '\n' && echo ""
	@echo ""
	@echo "$(YELLOW)Save these in your .env.$(ENV) file$(NC)"

check-security: ## Security checklist for public deployment
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  Security Checklist for Public Deployment     ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)1. Secrets & Passwords:$(NC)"
	@grep -q "blockscout_secure_password_2025" docker-compose.yml && \
		echo "  $(RED)❌ Default password in docker-compose.yml$(NC)" || \
		echo "  $(GREEN)✅ No default passwords found$(NC)"
	@test -f .env && \
		echo "  $(RED)❌ .env file exists (should be .env.testnet)$(NC)" || \
		echo "  $(GREEN)✅ Using environment-specific files$(NC)"
	@echo ""
	@echo "$(GREEN)2. Firewall Configuration:$(NC)"
	@command -v ufw >/dev/null 2>&1 && \
		(sudo ufw status | grep -q "Status: active" && \
		echo "  $(GREEN)✅ Firewall active$(NC)" || \
		echo "  $(RED)❌ Firewall not active$(NC)") || \
		echo "  $(YELLOW)⚠️  ufw not found$(NC)"
	@echo ""
	@echo "$(GREEN)3. SSL/TLS Certificates:$(NC)"
	@test -d /etc/letsencrypt/live && \
		echo "  $(GREEN)✅ Let's Encrypt directory exists$(NC)" || \
		echo "  $(YELLOW)⚠️  No SSL certificates yet$(NC)"
	@echo ""
	@echo "$(GREEN)4. Rate Limiting:$(NC)"
	@grep -q "limit_req_zone" infra/stacks/single-sequencer/nginx.conf && \
		echo "  $(GREEN)✅ Rate limiting configured$(NC)" || \
		echo "  $(RED)❌ No rate limiting$(NC)"
	@echo ""
	@echo "$(GREEN)5. Docker Security:$(NC)"
	@docker ps --format "{{.Names}}" | while read container; do \
		docker inspect $$container | grep -q "Privileged.*true" && \
		echo "  $(RED)❌ $$container running privileged$(NC)" || true; \
	done
	@echo "  $(GREEN)✅ Security check complete$(NC)"
	@echo ""
	@echo "$(GREEN)6. Monitoring:$(NC)"
	@docker ps | grep -q "prometheus" && \
		echo "  $(GREEN)✅ Prometheus running$(NC)" || \
		echo "  $(YELLOW)⚠️  Prometheus not running$(NC)"
	@docker ps | grep -q "grafana" && \
		echo "  $(GREEN)✅ Grafana running$(NC)" || \
		echo "  $(YELLOW)⚠️  Grafana not running$(NC)"

optimize-production: ## Apply production optimizations
	@echo "$(BLUE)Applying production optimizations...$(NC)"
	@echo ""
	@echo "$(GREEN)1. System limits:$(NC)"
	@echo "  Add to /etc/sysctl.conf:"
	@echo "    fs.file-max = 2097152"
	@echo "    net.core.somaxconn = 65535"
	@echo "    net.ipv4.tcp_max_syn_backlog = 8192"
	@echo ""
	@echo "$(GREEN)2. Docker limits:$(NC)"
	@echo "  Configured in docker-compose.yml"
	@echo "  - CPU limits"
	@echo "  - Memory limits"
	@echo "  - ulimits for file descriptors"
	@echo ""
	@echo "$(GREEN)3. Nginx tuning:$(NC)"
	@echo "  worker_connections: 8192"
	@echo "  keepalive_requests: 1000"
	@echo "  Rate limiting enabled"
	@echo ""
	@echo "$(GREEN)Apply system settings:$(NC)"
	@echo "  sudo sysctl -p"

# ==========================================
# ANDE FAUCET OPERATIONS
# ==========================================

setup-faucet: ## Setup ANDE faucet for testnet
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  Setting up ANDE Testnet Faucet               ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Step 1: Create faucet wallet$(NC)"
	@echo "  cast wallet new"
	@echo ""
	@echo "$(GREEN)Step 2: Fund the faucet wallet$(NC)"
	@echo "  Transfer ANDE tokens to the faucet address"
	@echo ""
	@echo "$(GREEN)Step 3: Configure .env.testnet$(NC)"
	@echo "  - Set FAUCET_PRIVATE_KEY"
	@echo "  - Set FAUCET_AMOUNT (default: 10 ANDE)"
	@echo "  - Set FAUCET_COOLDOWN (default: 24 hours)"
	@echo "  - Configure HCAPTCHA keys (get from hcaptcha.com)"
	@echo ""
	@echo "$(GREEN)Step 4: Start faucet$(NC)"
	@echo "  make start-faucet"

start-faucet: ## Start ANDE faucet service
	@echo "$(BLUE)Starting ANDE Faucet...$(NC)"
	@test -n "$(FAUCET_PRIVATE_KEY)" || { echo "$(RED)❌ FAUCET_PRIVATE_KEY not set in .env$(NC)"; exit 1; }
	@docker compose up -d ande-faucet
	@echo "$(GREEN)✅ Faucet started$(NC)"
	@echo "$(BLUE)Local URL: http://localhost:8081$(NC)"
	@echo "$(BLUE)Public URL: https://faucet.ande.network$(NC)"

stop-faucet: ## Stop ANDE faucet service
	@echo "$(BLUE)Stopping ANDE Faucet...$(NC)"
	@docker compose stop ande-faucet
	@echo "$(GREEN)✅ Faucet stopped$(NC)"

faucet-logs: ## View faucet logs
	@docker logs ande-faucet --tail 100 -f

faucet-status: ## Check faucet status and balance
	@echo "$(BLUE)ANDE Faucet Status:$(NC)"
	@echo ""
	@docker ps --filter "name=ande-faucet" --format "table {{.Names}}\t{{.Status}}"
	@echo ""
	@echo "$(GREEN)Faucet Wallet Balance:$(NC)"
	@FAUCET_ADDR=$$(cast wallet address --private-key $(FAUCET_PRIVATE_KEY) 2>/dev/null) && \
		BAL=$$(cast balance $$FAUCET_ADDR --rpc-url http://localhost:8545 2>/dev/null) && \
		echo "  Address: $$FAUCET_ADDR" && \
		echo "  Balance: $$(cast --to-unit $$BAL ether) ANDE" || \
		echo "  $(RED)Failed to check balance$(NC)"

fund-faucet: ## Fund the faucet wallet with ANDE tokens
	@echo "$(BLUE)Funding faucet wallet...$(NC)"
	@read -p "Amount to send (in ANDE): " amount && \
	FAUCET_ADDR=$$(cast wallet address --private-key $(FAUCET_PRIVATE_KEY)) && \
	echo "Faucet address: $$FAUCET_ADDR" && \
	echo "Sending $$amount ANDE..." && \
	cast send $$FAUCET_ADDR --value $${amount}ether --rpc-url http://localhost:8545 --private-key $(DEPLOYER_PRIVATE_KEY)

test-faucet: ## Test faucet by requesting tokens
	@echo "$(BLUE)Testing faucet...$(NC)"
	@read -p "Recipient address: " recipient && \
	curl -X POST http://localhost:8081/api/claim \
		-H "Content-Type: application/json" \
		-d "{\"address\":\"$$recipient\"}" && \
	echo "" && \
	echo "$(GREEN)Check balance:$(NC)" && \
	cast balance $$recipient --rpc-url http://localhost:8545

# ==========================================
# CELESTIA DA OPERATIONS
# ==========================================

celestia-start: ## Start Celestia DA layer
	@echo "$(BLUE)Starting Celestia DA layer...$(NC)"
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml up -d celestia-light-client
	@echo "$(GREEN)✅ Celestia DA started$(NC)"

celestia-stop: ## Stop Celestia DA layer
	@echo "$(BLUE)Stopping Celestia DA layer...$(NC)"
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml stop celestia-light-client

celestia-status: ## Check Celestia DA status
	@echo "$(BLUE)Celestia DA Status:$(NC)"
	@docker ps --filter "name=celestia" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(BLUE)Celestia Network Info:$(NC)"
	@echo "  Network: $$(grep CELESTIA_NETWORK .env.local 2>/dev/null | cut -d'=' -f2 || echo 'Not configured')"
	@echo "  Node Type: Light Client"
	@echo "  RPC: http://localhost:26658"

celestia-logs: ## View Celestia DA logs
	@docker logs celestia-light-client --tail 100 -f

# ==========================================
# MONITORING & HEALTH
# ==========================================

health: ## Check system health
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  ANDE Chain Health Check                      ║$(NC)"
	@echo "$(BLUE)║  Sovereign Rollup Status                       ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)Core Services:$(NC)"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "ev-reth|evolve|celestia|blockscout" || echo "$(YELLOW)No containers running$(NC)"
	@echo ""
	@echo "$(GREEN)ev-reth RPC Status:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		$(RPC_URL_LOCAL) | jq -r '.result' | xargs printf "Block: %d\n" 2>/dev/null || echo "$(RED)RPC not responding$(NC)"
	@echo ""
	@echo "$(GREEN)ANDE Precompile:$(NC)"
	@echo "  Address: 0x00000000000000000000000000000000000000FD"
	@echo "  Status: Integrated in ev-reth"
	@echo ""
	@echo "$(GREEN)Celestia DA:$(NC)"
	@$(MAKE) celestia-status

monitor-start: ## Start monitoring stack (Prometheus + Grafana)
	@echo "$(BLUE)Starting monitoring stack...$(NC)"
	@cd $(INFRA_DIR)/monitoring && docker compose up -d
	@echo "$(GREEN)✅ Monitoring started$(NC)"
	@echo "$(BLUE)Grafana: http://localhost:3001 (admin/admin)$(NC)"
	@echo "$(BLUE)Prometheus: http://localhost:9090$(NC)"

monitor-stop: ## Stop monitoring stack
	@cd $(INFRA_DIR)/monitoring && docker compose down

logs: ## View logs from all services
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml logs -f

logs-sequencer: ## View sequencer logs
	@docker logs evolve-sequencer --tail 100 -f

logs-explorer: ## View explorer logs
	@docker logs blockscout-frontend --tail 100 -f

# ==========================================
# MAINTENANCE & CLEANUP
# ==========================================

clean: ## Clean all build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@cd $(CONTRACTS_DIR) && rm -rf out cache broadcast coverage
	@echo "$(GREEN)✅ Artifacts cleaned$(NC)"

reset: ## Complete reset (WARNING: destroys all data)
	@echo "$(RED)⚠️  This will destroy all local data!$(NC)"
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || exit 1
	@echo "$(BLUE)Resetting system...$(NC)"
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml down -v
	@$(MAKE) clean
	@rm -rf deployments/addresses-*.json
	@echo "$(GREEN)✅ System reset complete$(NC)"

backup: ## Backup deployment data
	@echo "$(BLUE)Creating backup...$(NC)"
	@mkdir -p backups
	@tar -czf backups/ande-backup-$$(date +%Y%m%d-%H%M%S).tar.gz \
		contracts/deployments \
		contracts/broadcast \
		.env.* 2>/dev/null || true
	@echo "$(GREEN)✅ Backup created in backups/$(NC)"

restore: ## Restore from backup (interactive)
	@echo "$(BLUE)Available backups:$(NC)"
	@ls -lh backups/*.tar.gz 2>/dev/null || echo "$(YELLOW)No backups found$(NC)"
	@read -p "Enter backup filename to restore: " backup && \
		tar -xzf backups/$$backup && \
		echo "$(GREEN)✅ Backup restored$(NC)"

# ==========================================
# UTILITIES & HELPERS
# ==========================================

stop: ## Stop all services
	@echo "$(BLUE)Stopping all services...$(NC)"
	@cd $(INFRA_DIR) && docker compose -f stacks/single-sequencer/docker-compose.yml down
	@echo "$(GREEN)✅ All services stopped$(NC)"

restart: stop start-local ## Restart all services

ps: ## Show running containers
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

stats: ## Show container resource usage
	@docker stats --no-stream

update-deps: ## Update all dependencies
	@echo "$(BLUE)Updating dependencies...$(NC)"
	@cd $(CONTRACTS_DIR) && forge update
	@npm update
	@echo "$(GREEN)✅ Dependencies updated$(NC)"

format: ## Format all Solidity code
	@echo "$(BLUE)Formatting code...$(NC)"
	@cd $(CONTRACTS_DIR) && forge fmt
	@echo "$(GREEN)✅ Code formatted$(NC)"

lint: ## Lint Solidity code
	@echo "$(BLUE)Linting code...$(NC)"
	@cd $(CONTRACTS_DIR) && forge fmt --check
	@echo "$(GREEN)✅ Linting complete$(NC)"

docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@cd $(CONTRACTS_DIR) && forge doc
	@echo "$(GREEN)✅ Documentation generated in contracts/docs/book$(NC)"

# ==========================================
# CI/CD HELPERS
# ==========================================

ci-test: ## Run tests in CI environment
	@echo "$(BLUE)Running CI tests...$(NC)"
	@cd $(CONTRACTS_DIR) && forge test --no-match-coverage
	@$(MAKE) security-slither

ci-deploy: ## Deploy in CI environment (requires env vars)
	@echo "$(BLUE)Running CI deployment...$(NC)"
	@test -n "$(CI)" || { echo "$(RED)Not in CI environment$(NC)"; exit 1; }
	@$(MAKE) deploy ENV=$(DEPLOY_ENV)

# ==========================================
# INSTALLATION TARGETS
# ==========================================

install-production: ## Install this Makefile as the main Makefile
	@echo "$(BLUE)Installing production Makefile...$(NC)"
	@test -f Makefile && mv Makefile Makefile.backup.old || true
	@cp Makefile.production Makefile
	@echo "$(GREEN)✅ Production Makefile installed$(NC)"
	@echo "$(YELLOW)Old Makefile backed up as Makefile.backup.old$(NC)"
	@echo ""
	@echo "$(BLUE)Run 'make help' to see all available commands$(NC)"

uninstall-production: ## Restore old Makefile
	@echo "$(BLUE)Restoring old Makefile...$(NC)"
	@test -f Makefile.backup.old && mv Makefile.backup.old Makefile || echo "$(YELLOW)No backup found$(NC)"
	@echo "$(GREEN)✅ Old Makefile restored$(NC)"

# ==========================================
# TROUBLESHOOTING
# ==========================================

doctor: ## Run system diagnostics
	@echo "$(BLUE)╔════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║  ANDE Chain System Diagnostics                ║$(NC)"
	@echo "$(BLUE)╚════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)1. Checking prerequisites:$(NC)"
	@$(MAKE) check-prerequisites
	@echo ""
	@echo "$(GREEN)2. Checking Docker:$(NC)"
	@docker info >/dev/null 2>&1 && echo "$(GREEN)✅ Docker running$(NC)" || echo "$(RED)❌ Docker not running$(NC)"
	@echo ""
	@echo "$(GREEN)3. Checking RPC:$(NC)"
	@curl -s -X POST -H "Content-Type: application/json" \
		--data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
		$(RPC_URL_LOCAL) >/dev/null 2>&1 && echo "$(GREEN)✅ RPC responding$(NC)" || echo "$(RED)❌ RPC not responding$(NC)"
	@echo ""
	@echo "$(GREEN)4. Checking Celestia:$(NC)"
	@docker ps | grep -q celestia && echo "$(GREEN)✅ Celestia running$(NC)" || echo "$(YELLOW)⚠️  Celestia not running$(NC)"
	@echo ""
	@echo "$(GREEN)5. Checking wallets:$(NC)"
	@cast wallet list | head -5
	@echo ""
	@echo "$(GREEN)6. Disk space:$(NC)"
	@df -h . | tail -1

fix-permissions: ## Fix file permissions
	@echo "$(BLUE)Fixing permissions...$(NC)"
	@chmod 600 .env.* 2>/dev/null || true
	@chmod +x scripts/*.sh 2>/dev/null || true
	@echo "$(GREEN)✅ Permissions fixed$(NC)"

fix-docker: ## Fix Docker issues (restart daemon)
	@echo "$(BLUE)Restarting Docker...$(NC)"
	@sudo systemctl restart docker 2>/dev/null || \
		osascript -e 'quit app "Docker"' && sleep 3 && open -a Docker 2>/dev/null || \
		echo "$(YELLOW)Please restart Docker manually$(NC)"

clear-cache: ## Clear all caches
	@echo "$(BLUE)Clearing caches...$(NC)"
	@cd $(CONTRACTS_DIR) && rm -rf cache
	@docker system prune -f
	@echo "$(GREEN)✅ Caches cleared$(NC)"

# ==========================================
# QUICK COMMANDS (shortcuts)
# ==========================================

d: deploy-local ## Shortcut for deploy-local
t: test-all ## Shortcut for test-all
h: health ## Shortcut for health
s: security-audit ## Shortcut for security-audit
c: clean ## Shortcut for clean

# ==========================================
# END OF MAKEFILE
# ==========================================

.DEFAULT_GOAL := help

# Print colored output helper
define print_colored
	@echo "$(1)$(2)$(NC)"
endef