#!/bin/bash

# Kong API Gateway Deployment Script

set -e

echo "🚪 Deploying Kong API Gateway..."

# Add Kong Helm repository
helm repo add kong https://charts.konghq.com
helm repo update

# Deploy Kong
helm upgrade --install kong kong/kong \
  --namespace aurora-dev \
  --values infrastructure/helm-charts/kong/values.yaml \
  --set ingressController.installCRDs=false

# Wait for Kong to be ready
echo "⏳ Waiting for Kong to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong \
  --namespace aurora-dev --timeout=300s

# Get Kong proxy URL
KONG_PROXY=$(kubectl get svc kong-kong-proxy -n aurora-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$KONG_PROXY" ]; then
    KONG_PROXY="localhost"  # Fallback for minikube
fi

echo "✅ Kong API Gateway deployed!"
echo "🌐 Kong Admin URL: http://$KONG_PROXY:8001"
echo "🔗 Kong Proxy URL: http://$KONG_PROXY:80"
echo "📚 Kong documentation available at: http://$KONG_PROXY:8001/docs"
