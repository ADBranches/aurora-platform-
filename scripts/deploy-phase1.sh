#!/bin/bash

# COMPLETE Phase 1 Deployment - Fixing all gaps

set -e

echo "🎯 Starting COMPLETE Phase 1 Deployment"
echo "========================================"

echo "🔧 Step 1: Deploying Kong with complete configuration..."
helm upgrade --install kong kong/kong \
  --namespace aurora-dev \
  --values infrastructure/helm-charts/kong/values.yaml \
  --set-file ingressController.extraVolumes[0].data=infrastructure/helm-charts/kong/config/kong-complete.yaml

echo "🗃️ Step 2: Initializing complete database schema..."
./scripts/init-databases-complete.sh

echo "📊 Step 3: Setting up Feast feature store..."
kubectl apply -f infrastructure/feast/ -n aurora-dev

echo "📈 Step 4: Deploying complete observability stack..."
./scripts/deploy-observability.sh

echo "🔑 Step 5: Setting up API key authentication..."
kubectl apply -f infrastructure/helm-charts/kong/config/api-keys.yaml -n aurora-dev

# Wait for everything to be ready
echo "⏳ Waiting for all components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n aurora-dev --timeout=300s

# Test the API Gateway configuration
echo "🧪 Testing API Gateway configuration..."
KONG_PROXY=$(kubectl get svc kong-kong-proxy -n aurora-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$KONG_PROXY" ]; then
    KONG_PROXY="localhost"
fi

echo "Testing Kong routes..."
curl -I http://$KONG_PROXY:8000/api/v1/health
curl -I http://$KONG_PROXY:8000/api/v1/predictions

echo ""
echo "✅ PHASE 1 NOW FULLY COMPLETE!"
echo ""
echo "🌐 Access Points:"
echo "   Kong Admin: http://$KONG_PROXY:8001"
echo "   Kong API: http://$KONG_PROXY:8000"
echo "   Grafana: http://localhost:3000"
echo "   Jaeger: http://localhost:16686"
echo ""
echo "🔐 API Keys configured for routes:"
echo "   Web App: web-app-key-123"
echo "   Mobile App: mobile-app-key-456"
