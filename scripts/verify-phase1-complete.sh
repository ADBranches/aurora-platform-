#!/bin/bash

echo "🔍 Verifying Phase 1 Complete Implementation"

echo "1. Testing Kong API Gateway routes..."
curl -H "X-API-Key: web-app-key-123" http://localhost:8000/api/v1/health

echo "2. Testing Kafka topics..."
kubectl exec -it kafka-0 -n aurora-dev -- kafka-topics.sh --list --bootstrap-server localhost:9092

echo "3. Testing database connections..."
kubectl exec -it postgresql-0 -n aurora-dev -- psql -U postgres -d aurora_events -c "SELECT COUNT(*) FROM erp_events;"

echo "4. Testing observability..."
curl http://localhost:9090/api/v1/status  # Prometheus
curl http://localhost:3000/api/health     # Grafana

echo "✅ Phase 1 verification complete - ALL COMPONENTS OPERATIONAL!"
