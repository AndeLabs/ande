# 🐳 Smart Contracts Dockerfile - AndeChain
FROM ghcr.io/foundry-rs/foundry:latest

# Install Python and security tools
USER root
RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-venv && \
    pip3 install slither-analyzer && \
    rm -rf /var/lib/apt/lists/*
USER foundry

# Set working directory
WORKDIR /app

# Copy foundry configuration first (for better layer caching)
COPY foundry.toml ./
COPY remappings.txt ./

# Copy library dependencies
COPY lib/ ./lib

# Copy source code
COPY src/ ./src
COPY test/ ./test
COPY script/ ./script

# Build contracts
RUN forge build

# Install Node.js for Gemini analysis scripts
USER root
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g @google/generative-ai && \
    rm -rf /var/lib/apt/lists/*
USER foundry

# Note: CI scripts handled in CI/CD pipeline, not in local development

# Set permissions back to foundry user
USER foundry

# Expose volume for test results and artifacts
VOLUME ["/app/artifacts", "/app/test-results", "/app/coverage"]

# Default command - run tests
CMD ["forge", "test", "--gas-report"]