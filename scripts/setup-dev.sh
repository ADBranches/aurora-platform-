#!/bin/bash

# Aurora Platform Development Setup Script

set -e

echo "🚀 Setting up Aurora development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "Docker is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting."; exit 1; }

# Create environment file
if [ ! -f .env ]; then
    cat > .env << EOF
# Development Environment Variables
ENVIRONMENT=development
LOG_LEVEL=debug

# Registry Configuration
REGISTRY_URL=docker.io
REGISTRY_NAMESPACE=aurora

# Kubernetes Configuration
K8S_NAMESPACE=aurora-dev

# Application Configuration
API_VERSION=v1alpha1
EOF
    echo "✅ Created .env file"
fi

# Make scripts executable
chmod +x scripts/*.sh

echo "✅ Development environment setup complete!"
echo "📝 Next steps:"
echo "   1. Run: ./scripts/setup-k8s.sh"
echo "   2. Run: ./scripts/deploy-infra.sh"
