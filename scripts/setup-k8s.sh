#!/bin/bash

# Kubernetes Cluster Setup Script

set -e

echo "🔧 Setting up Kubernetes cluster..."

# Check system resources
echo "📊 Checking system resources..."
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
AVAILABLE_MEM=$(free -m | awk '/^Mem:/{print $7}')
CPU_CORES=$(nproc)

echo "💾 Total RAM: ${TOTAL_MEM}MB"
echo "💾 Available RAM: ${AVAILABLE_MEM}MB" 
echo "⚡ CPU Cores: ${CPU_CORES}"

# Calculate safe memory allocation (70% of available or max 4096MB)
MEM_ALLOCATION=$((AVAILABLE_MEM * 70 / 100))
if [ $MEM_ALLOCATION -gt 4096 ]; then
    MEM_ALLOCATION=4096
fi
if [ $MEM_ALLOCATION -lt 2048 ]; then
    MEM_ALLOCATION=2048
fi

# Calculate safe CPU allocation (50% of total cores)
CPU_ALLOCATION=$((CPU_CORES / 2))
if [ $CPU_ALLOCATION -lt 2 ]; then
    CPU_ALLOCATION=2
fi

echo "🎯 Allocating: ${MEM_ALLOCATION}MB memory, ${CPU_ALLOCATION} CPUs"

# Check if minikube is installed, if not install it
if ! command -v minikube &> /dev/null; then
    echo "📦 Installing minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
fi

# Stop existing minikube cluster if running
if minikube status | grep -q "host: Running"; then
    echo "🛑 Stopping existing minikube cluster..."
    minikube stop
fi

# Start minikube cluster with dynamic resource allocation
echo "🚀 Starting minikube cluster..."
minikube start --cpus=${CPU_ALLOCATION} --memory=${MEM_ALLOCATION} --disk-size=20g

# Enable required addons
echo "⚙️ Enabling Kubernetes addons..."
minikube addons enable ingress
minikube addons enable metrics-server

# Create development namespace
kubectl create namespace aurora-dev --dry-run=client -o yaml | kubectl apply -f -

# Configure docker to use minikube's daemon
eval $(minikube docker-env)

echo "✅ Kubernetes cluster setup complete!"
echo "📊 Resource allocation:"
echo "   Memory: ${MEM_ALLOCATION}MB"
echo "   CPUs: ${CPU_ALLOCATION}"
echo "🌐 Dashboard URL: minikube dashboard"
echo "🔗 Ingress IP: minikube ip"
echo "📈 Cluster info: kubectl cluster-info"
