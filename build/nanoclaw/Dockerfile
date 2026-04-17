FROM node:22-bookworm-slim
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends docker.io && rm -rf /var/lib/apt/lists/*
COPY package.json package-lock.json* ./
RUN npm pkg delete scripts.prepare && npm ci --production
COPY dist/ ./dist/
EXPOSE 8318
ENTRYPOINT ["node", "dist/index.js"]
