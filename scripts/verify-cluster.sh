#!/bin/bash
# Auto-reconnect if context is lost
kubectl config use-context minikube 2>/dev/null || true

# for advanced persistence.....
if ! kubectl cluster-info &>/dev/null; then
    echo "🔧 Reconfiguring kubectl context..."
    minikube start 2>/dev/null || true
    eval $(minikube docker-env 2>/dev/null) || true
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

minikube update-context