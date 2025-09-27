#!/bin/bash

# Add this check at the beginning of verify-cluster.sh
if ! kubectl cluster-info &>/dev/null; then
    echo "❌ Kubernetes cluster is not running or not configured"
    echo "💡 Start with: minikube start --driver=docker"
    exit 1
fi

# Kubernetes Cluster Verification Script

echo "🔍 Verifying Kubernetes cluster status..."

# Check cluster info
echo "📊 Cluster information:"
kubectl cluster-info

# Check nodes
echo "🖥️  Node status:"
kubectl get nodes -o wide

# Check if ingress controller is ready
echo "🌐 Ingress controller status:"
kubectl get pods -n ingress-nginx

# Check storage class
echo "💾 Storage classes:"
kubectl get storageclass

# Verify kubectl context
echo "🎯 Current context:"
kubectl config current-context

echo "✅ Cluster verification complete!"
