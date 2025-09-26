# Create services directory structure
mkdir -p services/api-gateway

# Create a simple Dockerfile for testing
cat > services/api-gateway/Dockerfile << 'EOF'
FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY . .

# Expose port
EXPOSE 3000

# Start command
CMD ["npm", "start"]
EOF
