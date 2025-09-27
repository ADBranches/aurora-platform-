#!/bin/bash

set -e

echo "🧪 Testing Phase 2 Data Flow..."

echo "1. Checking service status..."
kubectl get all -n aurora-dev

echo "2. Checking database connectivity..."
kubectl run postgres-test --rm -i --restart=Never --namespace aurora-dev \
  --image=postgres:15 \
  --env="PGPASSWORD=aurora123" -- \
  psql -h postgresql -U postgres -d aurora_events -c "SELECT '✅ Database OK' as status;"

echo "3. Checking Kafka connectivity..."
if kubectl get pods -n aurora-dev -l app=kafka --no-headers | grep -q Running; then
    echo "✅ Kafka pod is running"
    kubectl run kafka-test --rm -i --restart=Never --namespace aurora-dev \
      --image=bitnami/kafka:3.7 -- \
      /opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092
    echo "✅ Kafka connection successful"
else
    echo "❌ Kafka not running"
    exit 1
fi

echo "4. Checking Kafka topics..."
kubectl run kafka-check-topics --rm -i --restart=Never --namespace aurora-dev \
  --image=bitnami/kafka:3.7 -- \
  /opt/bitnami/kafka/bin/kafka-topics.sh --describe --bootstrap-server kafka:9092 --topic erp-events || echo "⚠️ erp-events topic not found"

echo "5. Testing Kong API Gateway..."
KONG_STATUS=$(kubectl get pods -n aurora-dev -l app.kubernetes.io/name=kong --no-headers | awk '{print $3}')
if [ "$KONG_STATUS" = "Running" ]; then
    echo "✅ Kong Gateway is running"
else
    echo "⚠️ Kong Gateway status: $KONG_STATUS"
fi

echo "✅ Phase 2 testing complete!"
