# ============================================================================
# Stage 1: Build local-da binary from ev-node source
# ============================================================================
FROM golang:1.24-alpine AS builder

LABEL org.opencontainers.image.source="https://github.com/andelabs/andechain"
LABEL org.opencontainers.image.description="Local Data Availability service for AndeChain development"
LABEL org.opencontainers.image.licenses="Apache-2.0"

WORKDIR /build

# Install build dependencies
RUN apk add --no-cache \
    make \
    git \
    ca-certificates

# Clone ev-node repository (using specific version for reproducibility)
ARG EV_NODE_VERSION=v1.0.0-beta.7
RUN git clone --depth 1 --branch ${EV_NODE_VERSION} https://github.com/evstack/ev-node.git .

# Download Go dependencies
RUN go mod download

# Build local-da binary
RUN make build-da

# Verify binary was built
RUN test -f /build/build/local-da && echo "✅ local-da binary built successfully"

# ============================================================================
# Stage 2: Create minimal runtime image
# ============================================================================
FROM alpine:3.18.3

LABEL org.opencontainers.image.source="https://github.com/andelabs/andechain"
LABEL org.opencontainers.image.description="Local Data Availability service for AndeChain development"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# Install runtime dependencies
RUN apk --no-cache add \
    ca-certificates \
    curl \
    tzdata

# Create non-root user for security
RUN addgroup -g 1000 ande && \
    adduser -D -u 1000 -G ande ande

WORKDIR /home/ande

# Copy binary from builder stage
COPY --from=builder --chown=ande:ande /build/build/local-da /usr/bin/local-da

# Switch to non-root user
USER ande

# Expose default local-da port
EXPOSE 7980

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:7980 || exit 1

# Default entrypoint and command
ENTRYPOINT ["/usr/bin/local-da"]
CMD ["-listen-all"]
