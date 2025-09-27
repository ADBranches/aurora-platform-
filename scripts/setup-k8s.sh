#!/bin/bash

# Kubernetes Cluster Setup Script

set -e

echo "🔧 Setting up Kubernetes cluster..."

# Check if minikube is installed, if not install it
if ! command -v minikube &> /dev/null; then
    echo "📦 Installing minikube..."
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
fi

# Start minikube cluster
echo "🚀 Starting minikube cluster..."
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable required addons
echo "⚙️ Enabling Kubernetes addons..."
minikube addons enable ingress
minikube addons enable metrics-server

# Create development namespace
kubectl create namespace aurora-dev --dry-run=client -o yaml | kubectl apply -f -

# Configure docker to use minikube's daemon
eval $(minikube docker-env)

echo "✅ Kubernetes cluster setup complete!"
echo "🌐 Dashboard URL: minikube dashboard"
echo "🔗 Ingress IP: minikube ip"
