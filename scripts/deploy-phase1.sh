#!/bin/bash

# Phase 1: Reusable Platform Components Deployment

set -e

echo "🎯 Starting Phase 1: Reusable Platform Components"
echo "=================================================="

# Deploy Kong API Gateway
echo ""
echo "🚪 Step 1/4: Deploying Kong API Gateway..."
./scripts/deploy-kong.sh

# Initialize databases
echo ""
echo "🗃️ Step 2/4: Initializing databases..."
./scripts/init-databases.sh

# Create Kafka topics
echo ""
echo "📨 Step 3/4: Setting up Kafka topics..."
kubectl apply -f infrastructure/kafka/topics.yaml -n aurora-dev

# Deploy observability stack
echo ""
echo "📊 Step 4/4: Deploying observability stack..."
./scripts/deploy-observability.sh

echo ""
echo "✅ Phase 1 deployment complete!"
echo ""
echo "🌐 Access Points:"
echo "   Kong API Gateway: kubectl port-forward -n aurora-dev svc/kong-kong-proxy 8000:80"
echo "   Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
echo "   PostgreSQL: kubectl port-forward -n aurora-dev svc/postgresql 5432:5432"
echo ""
echo "🔍 Verify deployment: kubectl get pods -n aurora-dev"
