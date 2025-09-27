#!/bin/bash

# Phase 2: Core Data & AI Services Deployment

set -e

echo "🎯 Starting Phase 2: Core Data & AI Services"
echo "============================================="

# Build Docker images
echo ""
echo "🐳 Step 1/4: Building Docker images..."

# Build ERP Connector
echo "Building ERP Connector..."
docker build -t aurora/erp-connector:latest services/erp-connector/

# Build External Data Ingestor
echo "Building External Data Ingestor..." 
docker build -t aurora/external-data-ingestor:latest services/external-data-ingestor/

# Build Prediction Service
echo "Building Prediction Service..."
docker build -t aurora/prediction-service:latest services/prediction-service/

# Deploy services to Kubernetes
echo ""
echo "🚀 Step 2/4: Deploying services to Kubernetes..."

# Deploy ERP Connector
kubectl apply -f services/erp-connector/k8s/deployment.yaml -n aurora-dev

# Deploy External Data Ingestor
kubectl apply -f services/external-data-ingestor/k8s/deployment.yaml -n aurora-dev

# Deploy Prediction Service
kubectl apply -f services/prediction-service/k8s/deployment.yaml -n aurora-dev

# Train and register ML model
echo ""
echo "🤖 Step 3/4: Training ML model..."
cd services/ml-pipeline
python scripts/train_inventory_model.py
python scripts/register_model.py
cd ../..

# Wait for services to be ready
echo ""
echo "⏳ Step 4/4: Waiting for services to be ready..."
kubectl wait --for=condition=ready pod -l app=erp-connector -n aurora-dev --timeout=180s
kubectl wait --for=condition=ready pod -l app=external-data-ingestor -n aurora-dev --timeout=180s
kubectl wait --for=condition=ready pod -l app=prediction-service -n aurora-dev --timeout=180s

echo ""
echo "✅ Phase 2 deployment complete!"
echo ""
echo "🔍 Verification commands:"
echo "   kubectl get pods -n aurora-dev"
echo "   kubectl logs -f deployment/erp-connector -n aurora-dev"
echo "   kubectl port-forward svc/prediction-service 8080:80 -n aurora-dev"
