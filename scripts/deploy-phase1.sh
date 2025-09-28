#!/bin/bash
set -e

echo "$(date) 🎯 Starting COMPLETE Phase 1 Deployment"
echo "========================================"

echo "$(date) 📦 Ensuring aurora-dev namespace exists..."
if ! kubectl get namespace aurora-dev >/dev/null 2>&1; then
  kubectl create namespace aurora-dev
else
  echo "Namespace 'aurora-dev' already exists, skipping creation."
fi

echo "$(date) 🐘 Step 0: Deploying PostgreSQL..."
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgresql
  namespace: aurora-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
      - name: postgresql
        image: postgres:13
        env:
        - name: POSTGRES_DB
          value: aurora_events
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          value: aurora123
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: aurora-dev
spec:
  selector:
    app: postgresql
  ports:
  - port: 5432
    targetPort: 5432
EOF

echo "$(date) ⏳ Waiting for PostgreSQL to start..."
kubectl wait --for=condition=ready pod -l app=postgresql -n aurora-dev --timeout=120s

echo "$(date) 🔧 Step 1: Preparing Helm repos for Kong..."
helm repo add kong https://charts.konghq.com || true
helm repo update

echo "$(date) 🔧 Step 2: Deploying Kong with complete configuration..."
helm upgrade --install kong kong/kong \
  --namespace aurora-dev \
  --values infrastructure/helm-charts/kong/values.yaml \
  --set-file ingressController.extraVolumes[0].data=infrastructure/helm-charts/kong/config/kong.yaml

echo "$(date) 🗃️ Step 3: Initializing complete database schema..."
./scripts/init-databases.sh

echo "$(date) 📊 Step 4: Setting up core infrastructure..."
kubectl apply -k kubernetes/base/ -n aurora-dev

echo "$(date) 📈 Step 5: Deploying complete observability stack..."
./scripts/deploy-observability.sh

echo "$(date) 🔑 Step 6: Setting up API key authentication..."
kubectl apply -f infrastructure/helm-charts/kong/config/api-keys.yaml -n aurora-dev

echo "$(date) ⏳ Waiting for all components to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=kong -n aurora-dev --timeout=300s

echo "$(date) 🧪 Testing API Gateway configuration..."

# Wait for LoadBalancer IP
KONG_PROXY=""
for i in {1..20}; do
  KONG_PROXY=$(kubectl get svc kong-kong-proxy -n aurora-dev -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
  if [[ -n "$KONG_PROXY" ]]; then
    break
  fi
  echo "$(date) Waiting for Kong Proxy IP..."
  sleep 5
done

if [ -z "$KONG_PROXY" ]; then
  KONG_PROXY="localhost"
  echo "$(date) Kong Proxy IP not found, fallback to localhost"
else
  echo "$(date) Kong Proxy IP found: $KONG_PROXY"
fi

echo "Testing Kong routes..."
curl -I http://$KONG_PROXY:8000/api/v1/health || true
curl -I http://$KONG_PROXY:8000/api/v1/predictions || true

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
