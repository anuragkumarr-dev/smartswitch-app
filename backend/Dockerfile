# Build stage
FROM node:22-alpine AS builder

WORKDIR /app
COPY package*.json tsconfig.json ./
RUN npm ci

COPY src/ ./src/
RUN npm run build

# Production runtime stage
FROM node:22-alpine AS runner

WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm ci --only=production

COPY --from=builder /app/dist ./dist

# Create volume mount point for SQLite database
RUN mkdir -p /data && chown -R node:node /data /app

USER node

EXPOSE 3000

CMD ["node", "dist/index.js"]
