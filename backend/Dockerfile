# ── Stage: production-ready slim Node image ──────────────────────────────────
FROM node:20-slim

# Non-root user for security
RUN groupadd --gid 1001 nodejs && \
    useradd --uid 1001 --gid nodejs --shell /bin/bash --create-home go4

WORKDIR /app

# Copy manifests first to leverage Docker layer cache
COPY package*.json ./

# Install ALL deps (nodemon is needed at runtime inside the container for dev)
RUN npm ci

# Copy source
COPY . .

# Create uploads dir and hand ownership to the non-root user BEFORE switching users.
# This is critical: the named volume (go4_uploads:/app/uploads) is seeded from this
# directory when first created. If it is root-owned here the go4 user cannot write
# files — causing EACCES at runtime.
RUN mkdir -p /app/uploads && chown -R go4:nodejs /app/uploads

# Switch to non-root
USER go4

# Container listens on 3000; host maps 5000 → 3000 via docker-compose
EXPOSE 3000

CMD ["npm", "start"]
