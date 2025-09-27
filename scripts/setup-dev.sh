#!/bin/bash

# Aurora Platform Development Setup Script

set -e

echo "🚀 Setting up Aurora development environment..."
echo "📋 Checking prerequisites..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check command with version
check_dependency() {
    local cmd=$1
    local recommended_version=$2
    local required=${3:-false}
    
    echo -n "🔍 Checking ${cmd}..."
    
    if command -v $cmd >/dev/null 2>&1; then
        local version=$($cmd --version 2>/dev/null | head -n1 || echo "unknown")
        echo -e "${GREEN} ✓ Found: ${version}${NC}"
        
        # Basic version check (if recommended version provided)
        if [[ -n "$recommended_version" ]]; then
            if echo "$version" | grep -q "$recommended_version"; then
                echo -e "   ${GREEN}✅ Version compatible${NC}"
            else
                echo -e "   ${YELLOW}⚠️  Version may not be optimal${NC}"
            fi
        fi
        return 0
    else
        echo -e "${RED} ✗ Not found${NC}"
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ Required dependency missing: ${cmd}${NC}"
            return 1
        else
            echo -e "${YELLOW}⚠️  Optional dependency missing: ${cmd}${NC}"
            return 0
        fi
    fi
}

# Function to check disk space
check_disk_space() {
    local required_gb=$1
    local available_gb=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
    
    echo -n "💾 Checking disk space (${required_gb}GB required)..."
    if [ "$available_gb" -ge "$required_gb" ]; then
        echo -e "${GREEN} ✓ Available: ${available_gb}GB${NC}"
    else
        echo -e "${RED} ✗ Insufficient: ${available_gb}GB available${NC}"
        return 1
    fi
}

# Function to check memory
check_memory() {
    local required_mb=$1
    local available_mb=$(free -m | awk '/^Mem:/{print $7}')
    
    echo -n "🧠 Checking memory (${required_mb}MB required)..."
    if [ "$available_mb" -ge "$required_mb" ]; then
        echo -e "${GREEN} ✓ Available: ${available_mb}MB${NC}"
    else
        echo -e "${YELLOW} ⚠️  Low memory: ${available_mb}MB available${NC}"
        echo -e "${YELLOW}   Consider closing applications to free up memory${NC}"
    fi
}

# Run comprehensive dependency checks
echo -e "\n${BLUE}=== Dependency Check ===${NC}"

# Required dependencies
check_dependency "docker" "20." "true"
check_dependency "kubectl" "1.28" "true"
check_dependency "minikube" "1.30" "true"

# Optional but recommended dependencies
echo -e "\n${BLUE}=== Recommended Dependencies ===${NC}"
check_dependency "helm" "3."
check_dependency "git" "2."
check_dependency "curl" "7."
check_dependency "jq" "1.6"  # For JSON parsing in scripts

# System resources check
echo -e "\n${BLUE}=== System Resources ===${NC}"
check_disk_space 20  # 20GB minimum
check_memory 4096    # 4GB recommended

# Docker daemon check
echo -e "\n${BLUE}=== Docker Status ===${NC}"
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${RED}❌ Docker daemon is not running${NC}"
    echo -e "${YELLOW}💡 Start Docker with: sudo systemctl start docker${NC}"
    exit 1
fi

# Kubernetes cluster accessibility check
echo -e "\n${BLUE}=== Kubernetes Access ===${NC}"
if kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"
    CURRENT_CONTEXT=$(kubectl config current-context)
    echo -e "   Context: ${CURRENT_CONTEXT}"
else
    echo -e "${YELLOW}⚠️  No active Kubernetes cluster found${NC}"
    echo -e "${YELLOW}💡 This is normal if you haven't set up the cluster yet${NC}"
fi

# Check for existing .env file and backup if needed
if [ -f .env ]; then
    echo -e "\n${BLUE}=== Environment Configuration ===${NC}"
    if [ ! -f .env.backup ]; then
        cp .env .env.backup
        echo -e "${YELLOW}📦 Backed up existing .env to .env.backup${NC}"
    else
        echo -e "${YELLOW}ℹ️  Existing .env.backup found, skipping backup${NC}"
    fi
fi

# Create/update environment file
echo -e "\n${BLUE}=== Creating Environment Configuration ===${NC}"
cat > .env << EOF
# Development Environment Variables
ENVIRONMENT=development
LOG_LEVEL=debug

# Database Configuration
POSTGRES_HOST=postgresql.aurora-dev.svc.cluster.local
POSTGRES_PORT=5432
POSTGRES_USER=aurora_user
POSTGRES_PASSWORD=aurora123
POSTGRES_DB=aurora_events

# Redis Configuration
REDIS_HOST=redis-master.aurora-dev.svc.cluster.local
REDIS_PORT=6379
REDIS_PASSWORD=aurora-redis-123

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS=kafka.aurora-dev.svc.cluster.local:9092

# Kubernetes Configuration
K8S_NAMESPACE=aurora-dev

# Registry Configuration
REGISTRY_URL=docker.io
REGISTRY_NAMESPACE=aurora

# Application Configuration
API_VERSION=v1alpha1

# Service URLs (will be updated after deployment)
AURORA_API_URL=http://aurora-api.aurora-dev.svc.cluster.local:8080
AURORA_UI_URL=http://aurora-ui.aurora-dev.svc.cluster.local:3000
EOF

echo -e "${GREEN}✅ Created/updated .env file${NC}"

# Make scripts executable
echo -e "\n${BLUE}=== Setting up Scripts ===${NC}"
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}✅ Made scripts executable${NC}"

# Create necessary directories
echo -e "\n${BLUE}=== Creating Directories ===${NC}"
mkdir -p {manifests,charts,config,logs,temp}
echo -e "${GREEN}✅ Created necessary directories${NC}"

# Final summary
echo -e "\n${GREEN}✅ Development environment setup complete!${NC}"
echo -e "\n${BLUE}📝 Next steps:${NC}"
echo -e "   1. ${GREEN}Run: ./scripts/setup-k8s.sh${NC} (Sets up Kubernetes cluster)"
echo -e "   2. ${GREEN}Run: ./scripts/deploy-infra.sh${NC} (Deploys infrastructure)"
echo -e "   3. ${GREEN}Run: ./scripts/build-push.sh${NC} (Builds and pushes Docker images)"
echo -e "   4. ${GREEN}Run: ./scripts/deploy-apps.sh${NC} (Deploys applications)"

echo -e "\n${YELLOW}💡 Useful commands:${NC}"
echo -e "   ${BLUE}• Check cluster status:${NC} kubectl get nodes, pods -A"
echo -e "   ${BLUE}• View logs:${NC} kubectl logs -f <pod-name> -n aurora-dev"
echo -e "   ${BLUE}• Open dashboard:${NC} minikube dashboard"
echo -e "   ${BLUE}• Get service URLs:${NC} minikube service list"

echo -e "\n${GREEN}🚀 Happy coding with Aurora Platform!${NC}"
