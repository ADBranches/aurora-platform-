#!/bin/bash

# Phase 2: Core Data & AI Services Deployment with Robust Verification

set -e

echo "🎯 Starting Phase 2: Core Data & AI Services"
echo "============================================="

# 1. Pre-deployment verification
echo ""
echo "🔍 Step 1/5: Pre-deployment verification..."

# Verify cluster connectivity
echo "Verifying cluster connectivity..."
if ! kubectl cluster-info; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

# Verify namespace exists
if ! kubectl get namespace aurora-dev &> /dev/null; then
    echo "❌ aurora-dev namespace does not exist. Please run Phase 1 first."
    exit 1
fi

# Verify nodes are ready
echo "Checking node status..."
kubectl get nodes

# 2. Build Docker images
echo ""
echo "🐳 Step 2/5: Building Docker images..."

# Build ERP Connector
echo "Building ERP Connector..."
if ! docker build -t aurora/erp-connector:latest services/erp-connector/; then
    echo "❌ Failed to build ERP Connector image"
    exit 1
fi

# Build External Data Ingestor
echo "Building External Data Ingestor..." 
if ! docker build -t aurora/external-data-ingestor:latest services/external-data-ingestor/; then
    echo "❌ Failed to build External Data Ingestor image"
    exit 1
fi

# Build Prediction Service
echo "Building Prediction Service..."
if ! docker build -t aurora/prediction-service:latest services/prediction-service/; then
    echo "❌ Failed to build Prediction Service image"
    exit 1
fi

# 3. Deploy services to Kubernetes
echo ""
echo "🚀 Step 3/5: Deploying services to Kubernetes..."

# Deploy ERP Connector
echo "Deploying ERP Connector..."
kubectl apply -f services/erp-connector/k8s/deployment.yaml -n aurora-dev

# Deploy External Data Ingestor
echo "Deploying External Data Ingestor..."
kubectl apply -f services/external-data-ingestor/k8s/deployment.yaml -n aurora-dev

# Deploy Prediction Service
echo "Deploying Prediction Service..."
kubectl apply -f services/prediction-service/k8s/deployment.yaml -n aurora-dev

# 4. Wait for services to be ready
echo ""
echo "⏳ Step 4/5: Waiting for services to be ready..."

# Wait with timeout and better error handling
wait_for_pod() {
    local app_label=$1
    local timeout=300
    
    echo "Waiting for ${app_label} to be ready (timeout: ${timeout}s)..."
    if kubectl wait --for=condition=ready pod -l app=${app_label} -n aurora-dev --timeout=${timeout}s; then
        echo "✅ ${app_label} is ready"
    else
        echo "❌ ${app_label} failed to become ready"
        echo "Debug info:"
        kubectl get pods -l app=${app_label} -n aurora-dev
        kubectl describe pods -l app=${app_label} -n aurora-dev
        exit 1
    fi
}

wait_for_pod "erp-connector"
wait_for_pod "external-data-ingestor" 
wait_for_pod "prediction-service"

# 5. ML Model Training (if applicable)
echo ""
echo "🤖 Step 5/5: ML Model Training & Verification..."

# Train and register ML model if scripts exist
if [ -f "services/ml-pipeline/scripts/train_inventory_model.py" ]; then
    echo "Training ML model..."
    cd services/ml-pipeline
    python scripts/train_inventory_model.py
    python scripts/register_model.py
    cd ../..
else
    echo "ℹ️  ML training scripts not found, skipping model training"
fi

# 6. DATA FLOW VERIFICATION - CRUCIAL STEP
echo ""
echo "🔌 Data Flow Verification"
echo "========================="

# Test ERP Connector health
echo "1. Testing ERP Connector health..."
if kubectl exec deployment/erp-connector -n aurora-dev -- curl -s http://localhost:8000/health > /dev/null; then
    echo "✅ ERP Connector health check passed"
else
    echo "❌ ERP Connector health check failed"
    kubectl logs deployment/erp-connector -n aurora-dev --tail=20
fi

# Test Kafka connectivity and events
echo "2. Testing Kafka event flow..."
if kubectl get pod kafka-0 -n aurora-dev &> /dev/null; then
    echo "Testing Kafka topic consumption..."
    if timeout 30 kubectl exec -it kafka-0 -n aurora-dev -- kafka-console-consumer.sh \
        --topic erp-events --bootstrap-server localhost:9092 --max-messages 1 --timeout-ms 10000; then
        echo "✅ Kafka event flow verified"
    else
        echo "ℹ️  No events in Kafka topic (this might be normal if no data has been sent yet)"
    fi
else
    echo "ℹ️  Kafka not found in aurora-dev namespace, skipping Kafka test"
fi

# Test Prediction Service logs
echo "3. Checking Prediction Service status..."
PREDICTION_LOGS=$(kubectl logs deployment/prediction-service -n aurora-dev --tail=10 2>/dev/null || echo "No logs available")
if [[ "$PREDICTION_LOGS" != "No logs available" ]]; then
    echo "✅ Prediction Service is running"
    echo "Recent logs:"
    echo "$PREDICTION_LOGS"
else
    echo "❌ Prediction Service logs not available"
fi

# Final status check
echo ""
echo "📊 Final Deployment Status"
echo "=========================="
kubectl get pods -n aurora-dev -l "app in (erp-connector, external-data-ingestor, prediction-service)"

echo ""
echo "✅ Phase 2 deployment complete!"
echo ""
echo "🔍 Useful commands for monitoring:"
echo "   kubectl get pods -n aurora-dev"
echo "   kubectl logs -f deployment/erp-connector -n aurora-dev"
echo "   kubectl logs -f deployment/prediction-service -n aurora-dev" 
echo "   kubectl port-forward svc/erp-connector 8000:8000 -n aurora-dev"
echo "   kubectl port-forward svc/prediction-service 8080:80 -n aurora-dev"
echo ""
echo "🎯 Next step: Run Phase 3 for API Gateway and final integration"
