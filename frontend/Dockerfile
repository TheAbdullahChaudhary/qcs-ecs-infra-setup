FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN [ -f package-lock.json ] || npm install && npm install --package-lock-only && npm ci --omit=dev

# Copy source code
COPY . .

# Set environment variables
ENV HOST=0.0.0.0
ENV REACT_APP_API_URL=/api

EXPOSE 3000

CMD ["npm", "start"]