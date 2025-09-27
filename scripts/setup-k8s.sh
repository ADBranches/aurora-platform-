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

# Minikube's minimum requirement (updated to 1900MB based on the warning)
MINIKUBE_MIN_MEM=1900

# Check if system has enough memory for Minikube
if [ $AVAILABLE_MEM -lt $MINIKUBE_MIN_MEM ]; then
    echo "❌ Insufficient RAM for Minikube minimum requirements"
    echo "   Available: ${AVAILABLE_MEM}MB, Required: ${MINIKUBE_MIN_MEM}MB"
    echo "💡 Tips to free up memory:"
    echo "   - Close unnecessary applications"
    echo "   - Restart your system"
    echo "   - Check running processes: ps aux --sort=-%mem | head"
    exit 1
fi

# Calculate safe resource allocation (use 60% of available)
MEM_ALLOCATION=$((AVAILABLE_MEM * 60 / 100))

# Ensure we meet Minikube's minimum and don't overallocate
if [ $MEM_ALLOCATION -lt $MINIKUBE_MIN_MEM ]; then
    MEM_ALLOCATION=$MINIKUBE_MIN_MEM
fi
if [ $MEM_ALLOCATION -gt 4096 ]; then
    MEM_ALLOCATION=4096
fi

# CPU allocation (conservative)
CPU_ALLOCATION=$((CPU_CORES / 2))
if [ $CPU_ALLOCATION -lt 2 ]; then
    CPU_ALLOCATION=2
fi
if [ $CPU_ALLOCATION -gt 4 ]; then
    CPU_ALLOCATION=4
fi

echo "🎯 Allocating: ${MEM_ALLOCATION}MB memory, ${CPU_ALLOCATION} CPUs"

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "📦 Installing minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
fi

# **FIXED: Better cluster detection and deletion**
echo "🔍 Checking for existing minikube clusters..."

# List all minikube profiles
EXISTING_PROFILES=$(minikube profile list -o json 2>/dev/null | grep -c "minikube" || true)

if [ "$EXISTING_PROFILES" -gt 0 ]; then
    echo "🛑 Found existing minikube cluster(s). Deleting..."
    
    # Stop all running minikube instances
    minikube stop 2>/dev/null || true
    
    # Delete the cluster forcefully
    minikube delete --all --purge
    
    # Additional cleanup for docker driver
    if docker ps -a | grep -q minikube; then
        echo "🧹 Cleaning up leftover docker containers..."
        docker stop minikube 2>/dev/null || true
        docker rm minikube 2>/dev/null || true
    fi
    
    echo "⏳ Waiting for cleanup to complete..."
    sleep 10
fi

# Start minikube cluster with dynamic resource allocation
echo "🚀 Starting minikube cluster..."
minikube start \
    --cpus=${CPU_ALLOCATION} \
    --memory=${MEM_ALLOCATION} \
    --disk-size=20g \
    --driver=docker \
    --force  # Force recreation if needed

# Enable required addons
echo "⚙️ Enabling Kubernetes addons..."
minikube addons enable ingress
minikube addons enable metrics-server

# Create development namespace
kubectl create namespace aurora-dev --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Kubernetes cluster setup complete!"
echo "📊 Resource allocation:"
echo "   Memory: ${MEM_ALLOCATION}MB"
echo "   CPUs: ${CPU_ALLOCATION}"
echo "🌐 Dashboard URL: minikube dashboard"
echo "🔗 Ingress IP: minikube ip"
echo "📈 Cluster info: kubectl cluster-info"

# Enhanced cluster verification
echo "🔍 Verifying cluster status..."
minikube status

echo "📋 Cluster details:"
kubectl cluster-info
kubectl get nodes -o wide

# Check critical system pods
echo "🔎 Checking system pod status..."
kubectl get pods -n kube-system -l tier=control-plane

# Verify addons are properly installed
echo "🔎 Verifying addons..."
kubectl get pods -n ingress-nginx
kubectl get pods -n kube-system -l k8s-app=metrics-server

echo "✅ Cluster is ready and verified!"
