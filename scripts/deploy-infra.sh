#!/bin/bash

# Infrastructure Deployment Script

set -e

echo "🏗️ Deploying Aurora infrastructure..."

# Create namespace if it doesn't exist
kubectl create namespace aurora-dev --dry-run=client -o yaml | kubectl apply -f -

# Deploy PostgreSQL
echo "📊 Deploying PostgreSQL..."
helm upgrade --install postgresql infrastructure/helm-charts/postgresql \
  --namespace aurora-dev \
  --values infrastructure/helm-charts/postgresql/values.yaml

# Deploy Redis
echo "🔴 Deploying Redis..."
helm upgrade --install redis infrastructure/helm-charts/redis \
  --namespace aurora-dev \
  --values infrastructure/helm-charts/redis/values.yaml

# Wait for services to be ready
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=postgresql \
  --namespace aurora-dev --timeout=300s

kubectl wait --for=condition=ready pod -l app=redis \
  --namespace aurora-dev --timeout=180s

# Display connection information
echo "✅ Infrastructure deployment complete!"
echo ""
echo "📋 Connection Information:"
echo "   PostgreSQL: postgresql.aurora-dev.svc.cluster.local:5432"
echo "   Redis: redis.aurora-dev.svc.cluster.local:6379"
echo ""
echo "🔍 Check status with: kubectl get pods -n aurora-dev"
