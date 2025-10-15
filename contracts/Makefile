# AndeChain Smart Contracts Makefile
# Provides convenient commands for development, testing, and deployment

.PHONY: help build test coverage clean deploy deploy-andeswap deploy-factory lint security format docs

# Default target
help:
	@echo "AndeChain Smart Contracts Development Commands:"
	@echo ""
	@echo "🔨 Build & Compile:"
	@echo "  build          - Compile all contracts"
	@echo "  clean          - Clean build artifacts"
	@echo ""
	@echo "🧪 Testing:"
	@echo "  test           - Run all tests"
	@echo "  test-dex       - Run DEX-specific tests"
	@echo "  test-factory   - Run Token Factory tests"
	@echo "  test-integration - Run integration tests"
	@echo "  coverage       - Generate test coverage report"
	@echo "  gas-report     - Generate gas usage report"
	@echo ""
	@echo "🚀 Deployment:"
	@echo "  deploy-local   - Deploy to local network"
	@echo "  deploy-andeswap - Deploy AndeSwap DEX"
	@echo "  deploy-factory - Deploy Token Factory"
	@echo "  deploy-all     - Deploy all contracts"
	@echo ""
	@echo "🔍 Analysis & Security:"
	@echo "  lint           - Run linter"
	@echo "  security       - Run Slither security analysis"
	@echo "  verify         - Verify contracts on Etherscan"
	@echo ""
	@echo "📝 Documentation:"
	@echo "  docs           - Generate documentation"
	@echo "  docs-serve     - Serve documentation locally"
	@echo ""
	@echo "🔧 Development:"
	@echo "  format         - Format code"
	@echo "  snapshot       - Update gas snapshots"
	@echo "  anvil          - Start local Anvil node"

# Build & Compile
build:
	@echo "🔨 Building contracts..."
	forge build
	@echo "✅ Build complete"

clean:
	@echo "🧹 Cleaning artifacts..."
	forge clean
	rm -rf out/
	rm -rf cache/
	@echo "✅ Clean complete"

# Testing
test:
	@echo "🧪 Running all tests..."
	forge test -vv
	@echo "✅ All tests complete"

test-dex:
	@echo "🧪 Running DEX tests..."
	forge test --match-path test/dex/* -vvv
	@echo "✅ DEX tests complete"

test-factory:
	@echo "🧪 Running Token Factory tests..."
	forge test --match-path test/factory/* -vvv
	@echo "✅ Token Factory tests complete"

test-integration:
	@echo "🧪 Running integration tests..."
	forge test --match-path test/integration/* -vvv
	@echo "✅ Integration tests complete"

test-fuzz:
	@echo "🧪 Running fuzz tests..."
	forge test --fuzz-runs 1000 -vv
	@echo "✅ Fuzz tests complete"

coverage:
	@echo "📊 Generating coverage report..."
	forge coverage --report lcov
	@echo "✅ Coverage report generated in coverage/"
	@echo "View with: genhtml coverage/lcov.info -o coverage/"

gas-report:
	@echo "⛽ Generating gas report..."
	forge test --gas-report
	@echo "✅ Gas report complete"

# Deployment
deploy-local:
	@echo "🚀 Deploying to local network..."
	forge script script/dex/DeployAndeSwap.s.sol:DeployAndeSwapTestnet --rpc-url local --broadcast --legacy
	forge script script/factory/DeployTokenFactory.s.sol:DeployTokenFactoryTestnet --rpc-url local --broadcast --legacy
	@echo "✅ Local deployment complete"

deploy-andeswap:
	@echo "🚀 Deploying AndeSwap DEX..."
	forge script script/dex/DeployAndeSwap.s.sol --rpc-url $(RPC_URL) --broadcast --legacy --verify
	@echo "✅ AndeSwap deployment complete"

deploy-factory:
	@echo "🚀 Deploying Token Factory..."
	forge script script/factory/DeployTokenFactory.s.sol --rpc-url $(RPC_URL) --broadcast --legacy --verify
	@echo "✅ Token Factory deployment complete"

deploy-all:
	@echo "🚀 Deploying all contracts..."
	$(MAKE) deploy-andeswap
	$(MAKE) deploy-factory
	@echo "✅ All contracts deployed"

deploy-testnet:
	@echo "🚀 Deploying to testnet..."
	forge script script/dex/DeployAndeSwap.s.sol:DeployAndeSwapTestnet --rpc-url $(TESTNET_RPC_URL) --broadcast --legacy --verify
	forge script script/factory/DeployTokenFactory.s.sol:DeployTokenFactoryTestnet --rpc-url $(TESTNET_RPC_URL) --broadcast --legacy --verify
	@echo "✅ Testnet deployment complete"

deploy-mainnet:
	@echo "🚀 Deploying to mainnet..."
	@echo "⚠️  WARNING: This will deploy to mainnet!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ]
	forge script script/dex/DeployAndeSwap.s.sol:DeployAndeSwapMainnet --rpc-url $(MAINNET_RPC_URL) --broadcast --legacy --verify
	forge script script/factory/DeployTokenFactory.s.sol:DeployTokenFactoryMainnet --rpc-url $(MAINNET_RPC_URL) --broadcast --legacy --verify
	@echo "✅ Mainnet deployment complete"

# Analysis & Security
lint:
	@echo "🔍 Running linter..."
	forge fmt --check
	@echo "✅ Lint complete"

format:
	@echo "📝 Formatting code..."
	forge fmt
	@echo "✅ Code formatted"

security:
	@echo "🔒 Running security analysis..."
	slither src/ --filter-paths "test/" --filter naming-convention,external-function,low-level-calls
	@echo "✅ Security analysis complete"

security-full:
	@echo "🔒 Running full security analysis..."
	slither src/ --filter-paths "test/"
	@echo "✅ Full security analysis complete"

verify:
	@echo "🔍 Verifying contracts..."
	@echo "Usage: make verify CONTRACT_ADDRESS=0x... RPC_URL=..."
	forge verify-contract $(CONTRACT_ADDRESS) "src/dex/AndeSwapPair.sol:AndeSwapPair" --chain-id $(CHAIN_ID) --verifier-url $(VERIFIER_URL) --etherscan-api-key $(ETHERSCAN_API_KEY)

# Documentation
docs:
	@echo "📚 Generating documentation..."
	@mkdir -p docs/generated
	@echo "# AndeChain Smart Contracts Documentation" > docs/generated/README.md
	@echo "" >> docs/generated/README.md
	@echo "## Contract Overview" >> docs/generated/README.md
	@echo "" >> docs/generated/README.md
	@for file in src/**/*.sol; do \
		echo "### $$file" >> docs/generated/README.md; \
		echo "" >> docs/generated/README.md; \
		grep -E "///|contract|interface" $$file | head -20 >> docs/generated/README.md; \
		echo "" >> docs/generated/README.md; \
	done
	@echo "✅ Documentation generated in docs/generated/"

docs-serve:
	@echo "🌐 Serving documentation..."
	@echo "Open http://localhost:8000 to view docs"
	cd docs/generated && python3 -m http.server 8000

# Development
snapshot:
	@echo "📸 Updating gas snapshots..."
	forge snapshot
	@echo "✅ Gas snapshots updated"

anvil:
	@echo "🔧 Starting local Anvil node..."
	anvil --fork-url $(FORK_URL) --fork-block-number $(FORK_BLOCK) --accounts 10 --balance 1000

# Gas Optimization
gas-optimize:
	@echo "⚡ Running gas optimization analysis..."
	forge test --gas-report --match-test test*
	@echo "✅ Gas optimization analysis complete"

# Size Analysis
size-analysis:
	@echo "📏 Analyzing contract sizes..."
	@for file in out/**/*.sol/*.json; do \
		if [ -f "$$file" ]; then \
			contract=$$(basename "$$file" .json); \
			size=$$(jq -r '.bytecode.object' "$$file" | wc -c); \
			echo "$$contract: $$size bytes"; \
		fi; \
	done

# Integration with AndeChain Infrastructure
start-infra:
	@echo "🚀 Starting AndeChain infrastructure..."
	cd .. && make start
	@echo "✅ Infrastructure started"

stop-infra:
	@echo "🛑 Stopping AndeChain infrastructure..."
	cd .. && make stop
	@echo "✅ Infrastructure stopped"

# CI/CD Helpers
ci-test:
	@echo "🧪 Running CI tests..."
	forge test --gas-report --no-match-test testFuzz
	@echo "✅ CI tests complete"

ci-build:
	@echo "🔨 Running CI build..."
	forge build
	forge fmt --check
	@echo "✅ CI build complete"

ci-security:
	@echo "🔒 Running CI security checks..."
	slither src/ --filter-paths "test/" --filter naming-convention --json slither-ci.json
	@echo "✅ CI security checks complete"

# Development Utilities
install:
	@echo "📦 Installing dependencies..."
	forge install foundry-rs/forge-std --no-commit
	forge install OpenZeppelin/openzeppelin-contracts --no-commit
	forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit
	@echo "✅ Dependencies installed"

update:
	@echo "🔄 Updating dependencies..."
	forge update
	@echo "✅ Dependencies updated"

# Quick Development Commands
dev-test: build test
	@echo "🚀 Quick dev test complete"

dev-deploy: build deploy-local
	@echo "🚀 Quick dev deployment complete"

dev-all: clean build test coverage
	@echo "🚀 Full dev cycle complete"

# Production Commands
prod-check: clean build test security lint
	@echo "✅ Production checks complete"

prod-deploy: prod-check deploy-all
	@echo "✅ Production deployment complete"

# Monitoring
monitor-gas:
	@echo "⛽ Monitoring gas usage..."
	watch -n 5 'make gas-report | tail -20'

monitor-tests:
	@echo "🧪 Monitoring test results..."
	watch -n 10 'forge test --no-match-test testFuzz --gas-report | tail -30'

# Help for specific areas
help-dex:
	@echo "AndeSwap DEX Commands:"
	@echo "  test-dex       - Run DEX tests"
	@echo "  deploy-andeswap - Deploy AndeSwap"
	@echo "  docs-dex       - Generate DEX documentation"

help-factory:
	@echo "Token Factory Commands:"
	@echo "  test-factory   - Run Token Factory tests"
	@echo "  deploy-factory - Deploy Token Factory"
	@echo "  docs-factory   - Generate Factory documentation"

# Environment Setup
setup-local:
	@echo "🔧 Setting up local environment..."
	@if [ ! -f .env ]; then echo "RPC_URL=http://localhost:8545" > .env; fi
	@if [ ! -d lib ]; then make install; fi
	@echo "✅ Local environment setup complete"

setup-testnet:
	@echo "🔧 Setting up testnet environment..."
	@echo "Please configure your .env file with TESTNET_RPC_URL and ETHERSCAN_API_KEY"
	@echo "Example:"
	@echo "TESTNET_RPC_URL=https://sepolia.infura.io/v3/YOUR_PROJECT_ID"
	@echo "ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY"
	@echo "CHAIN_ID=11155111"
	@echo "VERIFIER_URL=https://api-sepolia.etherscan.io/api"

# Advanced Commands
profile-gas:
	@echo "⚡ Profiling gas usage..."
	forge test --gas-report --match-profile gas
	@echo "✅ Gas profiling complete"

debug-contract:
	@echo "🐛 Debugging contract..."
	@echo "Usage: make debug-contract CONTRACT=ContractName TEST=testFunction"
	forge test --match-contract $(CONTRACT) --match-test $(TEST) -vvvv

# Batch Operations
batch-test:
	@echo "🧪 Running batch tests..."
	forge test --no-match-test testFuzz --gas-report
	forge test --match-test testFuzz --fuzz-runs 100
	@echo "✅ Batch testing complete"

batch-deploy:
	@echo "🚀 Running batch deployments..."
	forge script script/dex/DeployAndeSwap.s.sol --rpc-url $(RPC_URL) --broadcast --legacy --skip-simulation
	forge script script/factory/DeployTokenFactory.s.sol --rpc-url $(RPC_URL) --broadcast --legacy --skip-simulation
	@echo "✅ Batch deployment complete"

# Default environment variables
RPC_URL ?= http://localhost:8545
TESTNET_RPC_URL ?= https://sepolia.infura.io/v3/YOUR_PROJECT_ID
MAINNET_RPC_URL ?= https://mainnet.infura.io/v3/YOUR_PROJECT_ID
CHAIN_ID ?= 31337
VERIFIER_URL ?= http://localhost:4000/api
ETHERSCAN_API_KEY ?= dummy-key
FORK_URL ?= https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
FORK_BLOCK ?= latest

# Include local overrides
-include .env