FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Generate package-lock.json if it doesn't exist, then install dependencies
RUN [ -f package-lock.json ] || npm install && npm install --package-lock-only && npm ci --omit=dev

# Copy source code
COPY . .

EXPOSE 4000

CMD ["node", "index.js"]