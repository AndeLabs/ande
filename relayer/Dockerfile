# 🐳 Relayer Dockerfile - AndeChain Bridge Relayer
FROM node:20-alpine

# Set working directory
WORKDIR /app

# Install dependencies for building native modules
RUN apk add --no-cache python3 make g++

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY src/ ./src
COPY tsconfig.json ./

# Build the project
RUN npm run build

# Create non-root user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S relayer -u 1001

# Change ownership of the app directory
RUN chown -R relayer:nodejs /app
USER relayer

# Expose healthcheck port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node dist/healthcheck.js

# Default command
CMD ["npm", "start"]