#!/bin/bash

# Fix Kubernetes cluster issues
echo "🔧 Fixing Kubernetes cluster..."

# Stop and restart minikube
minikube stop
minikube delete
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Re-enable addons
minikube addons enable ingress
minikube addons enable metrics-server

# Reset kubectl context
kubectl config use-context minikube

# Verify fix
kubectl cluster-info
kubectl get nodes
