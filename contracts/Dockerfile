# Use a multi-stage build to keep the final image small

# 1. Builder stage: Install dependencies and build contracts
FROM ghcr.io/foundry-rs/foundry:latest as builder

# Set working directory
WORKDIR /app

# Copy foundry configuration and library dependencies first
COPY foundry.toml remappings.txt ./
COPY lib/ lib/

# Copy contract source and tests
COPY src/ src/
COPY test/ test/
COPY script/ script/

# Build the project
RUN forge build

# 2. Final stage: A minimal image with just the artifacts
FROM alpine:latest

WORKDIR /app

# Copy the compiled artifacts from the builder stage
# The output directory is configured in foundry.toml to be "artifacts"
COPY --from=builder /app/artifacts/ ./artifacts/

# The container doesn't need to run anything by default.
# It will be used as a volume mount or for `docker compose run` commands.
CMD ["sleep", "infinity"]