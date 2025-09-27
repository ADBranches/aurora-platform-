#!/bin/bash

# Test Phase 2 Data Flow

echo "🧪 Testing Phase 2 Data Flow..."

# Check if services are running
echo "1. Checking service status..."
kubectl get pods -n aurora-dev -l app.kubernetes.io/part-of=aurora

# Check Kafka topics
echo "2. Checking Kafka topics..."
kubectl exec -it kafka-0 -n aurora-dev -- kafka-topics.sh --list --bootstrap-server localhost:9092

# Check if events are flowing
echo "3. Checking ERP events in Kafka..."
kubectl exec -it kafka-0 -n aurora-dev -- kafka-console-consumer.sh \
  --topic erp-events \
  --bootstrap-server localhost:9092 \
  --from-beginning --max-messages 3

# Check predictions
echo "4. Checking predictions in Kafka..."
kubectl exec -it kafka-0 -n aurora-dev -- kafka-console-consumer.sh \
  --topic predictions-alerts \
  --bootstrap-server localhost:9092 \
  --from-beginning --max-messages 3

echo "✅ Phase 2 testing complete!"
