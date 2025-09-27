#!/bin/bash

set -e

echo "🧪 Testing Phase 2 Data Flow..."

# Clean up any existing test pods
kubectl delete pod kafka-test kafka-check-topics postgres-test --namespace aurora-dev --ignore-not-found=true --timeout=5s

echo "1. Checking service status..."
kubectl get all -n aurora-dev

echo "2. Checking database connectivity..."
kubectl run postgres-test-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
  --image=postgres:15 \
  --env="PGPASSWORD=aurora123" -- \
  psql -h postgresql -U postgres -d aurora_events -c "SELECT '✅ Database OK' as status;"

echo "3. Checking Kafka connectivity..."
if kubectl get pods -n aurora-dev -l app=kafka --no-headers | grep -q Running; then
    echo "✅ Kafka pod is running"
    # Wait a bit for Kafka to be fully ready
    sleep 10
    kubectl run kafka-test-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
      --image=bitnami/kafka:3.7 -- \
      /opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092
    echo "✅ Kafka connection successful"
else
    echo "❌ Kafka not running"
    exit 1
fi

echo "4. Creating Aurora topics if they don't exist..."
kubectl run kafka-create-topics-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
  --image=bitnami/kafka:3.7 -- \
  /bin/bash -c "
    /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic erp-events --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
    /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic predictions --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
    /opt/bitnami/kafka/bin/kafka-topics.sh --create --if-not-exists --topic audit-logs --partitions 1 --replication-factor 1 --bootstrap-server kafka:9092
    echo '✅ Topics created/verified'
  "

echo "5. Checking Kafka topics..."
kubectl run kafka-check-topics-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
  --image=bitnami/kafka:3.7 -- \
  /opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server kafka:9092

echo "6. Testing Kong API Gateway..."
KONG_STATUS=$(kubectl get pods -n aurora-dev -l app.kubernetes.io/name=kong --no-headers | awk '{print $3}')
if [ "$KONG_STATUS" = "Running" ]; then
    echo "✅ Kong Gateway is running"
    # Test Kong proxy
    kubectl run kong-test-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
      --image=curlimages/curl:8.15.0 -- \
      curl -s -o /dev/null -w "Kong status: %{http_code}\n" http://kong-kong-proxy:80 || echo "⚠️ Kong proxy not accessible internally"
else
    echo "⚠️ Kong Gateway status: $KONG_STATUS"
fi

echo "7. Testing data flow simulation..."
# Test producing a message to Kafka
kubectl run kafka-producer-test-$(date +%s) --rm -i --restart=Never --namespace aurora-dev \
  --image=bitnami/kafka:3.7 -- \
  /bin/bash -c "
    echo '{\"event_type\":\"test\",\"entity_id\":\"test-001\",\"payload\":{\"test\":\"data\"}}' | \
    /opt/bitnami/kafka/bin/kafka-console-producer.sh --topic erp-events --bootstrap-server kafka:9092
    echo '✅ Test message produced to erp-events topic'
  "

echo "✅ Phase 2 testing complete!"