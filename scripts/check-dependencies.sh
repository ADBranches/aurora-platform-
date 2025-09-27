#!/bin/bash

# Aurora Platform Dependency Check Script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Aurora Platform Dependency Check${NC}\n"

check_tool() {
    local tool=$1
    local required=$2
    local install_cmd=$3
    
    if command -v $tool >/dev/null 2>&1; then
        local version=$($tool --version 2>/dev/null | head -n1 | sed 's/^[^0-9]*//' || echo "unknown")
        echo -e "${GREEN}✅ $tool: $version${NC}"
        return 0
    else
        if [ "$required" = "true" ]; then
            echo -e "${RED}❌ $tool: MISSING (Required)${NC}"
            if [ -n "$install_cmd" ]; then
                echo -e "   💡 Install with: $install_cmd"
            fi
            return 1
        else
            echo -e "${YELLOW}⚠️  $tool: MISSING (Optional)${NC}"
            if [ -n "$install_cmd" ]; then
                echo -e "   💡 Install with: $install_cmd"
            fi
            return 0
        fi
    fi
}

# Required tools
echo -e "${BLUE}=== Required Tools ===${NC}"
check_tool "docker" "true" "curl -fsSL https://get.docker.com | sh"
check_tool "kubectl" "true" "curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && sudo install kubectl /usr/local/bin/"
check_tool "minikube" "true" "curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && sudo install minikube-linux-amd64 /usr/local/bin/"

# Recommended tools
echo -e "\n${BLUE}=== Recommended Tools ===${NC}"
check_tool "helm" "false" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
check_tool "git" "false" "sudo apt-get install git"
check_tool "jq" "false" "sudo apt-get install jq"
check_tool "curl" "false" "sudo apt-get install curl"

# System check
echo -e "\n${BLUE}=== System Resources ===${NC}"
# Memory
mem_total=$(free -m | awk '/^Mem:/{print $2}')
mem_available=$(free -m | awk '/^Mem:/{print $7}')
echo -e "💾 RAM: Total: ${mem_total}MB, Available: ${mem_available}MB"
if [ $mem_available -lt 2048 ]; then
    echo -e "${YELLOW}⚠️  Low memory available (< 2GB)${NC}"
fi

# Disk
disk_avail=$(df -h . | awk 'NR==2 {print $4}')
echo -e "💽 Disk space available: $disk_avail"

# Docker status
echo -e "\n${BLUE}=== Docker Status ===${NC}"
if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Docker daemon is running${NC}"
else
    echo -e "${RED}❌ Docker daemon is not accessible${NC}"
fi

echo -e "\n${GREEN}✅ Dependency check complete!${NC}"
